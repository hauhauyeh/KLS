-- =============================================================================
-- Sales_EnforceCartStock -- whole-unit flooring + full unit ratio. SEPARATE CHANGE
-- (web-unit-stock-restriction plan Phase 4, approved 2026-07-20): deploy AFTER
-- Phases 1-3 are live and reviewed; do not bundle with the 01 script.
--
-- 2026-07-20 changes vs baseline:
--   1) #Rows: BaseReqQty now uses the full ratio BaseQty = OrdQty * MultipleToBase
--      / FactorToBase. MultipleToBase is never snapshotted on TempSales -- joined
--      live from ItemUnit via t.ItemUnitId (same as TempSales_GetList).
--   2) FIFO loop: allocation is floored to WHOLE units of the line's unit; the
--      remainder returns to the stock pool for later lines of the same item.
--      ROUND(,4) before FLOOR -- 6dp base snapshots make a whole ÷12 unit arrive
--      as 0.999996, and a bare FLOOR would zero a fully-stocked line.
--   3) Writeback: AllocQty converts base back to unit qty with the full ratio.
--   On data where MultipleToBase = 1 everywhere (KLS), changes 1 and 3 are
--   behavior-neutral; change 2 only alters SHORT allocations (fractional cap ->
--   whole-unit floor). Full allocations are unchanged.
-- Baseline: KLS/SQL/2026-07-03/Sales_EnforceCartStock.sql
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Sales_EnforceCartStock]
GO


CREATE PROCEDURE [dbo].[Sales_EnforceCartStock]
    @SalesId INT,
    @PayeeId INT,
    @EmpId INT,
    @IsEdit BIT
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------------
    -- 0) Cap cart qty at available stock before inserting
    ----------------------------------------------------------------------
	DECLARE @EnforceStockLimit BIT = 0;

	SELECT @EnforceStockLimit = CASE WHEN SettingValue = 'true' THEN 1 ELSE 0 END
	FROM SystemSetting WHERE SettingKey = 'WEB_ENFORCE_STOCK_LIMIT';

    IF @EnforceStockLimit = 0
       RETURN;

    ----------------------------------------------------------------------
    -- 1) Working rows
    ----------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#Rows') IS NOT NULL
        DROP TABLE #Rows;

    SELECT
        t.TempSalesId,
        t.ItemId,
        OrdQty          = CONVERT(decimal(18,6), ISNULL(NULLIF(t.OrdQty, 0), 1)),
        FactorToBase    = CONVERT(decimal(18,6), ISNULL(NULLIF(t.FactorToBase, 0), 1.0)),
        -- [2026-07-20] live from ItemUnit (never snapshotted on TempSales)
        MultipleToBase  = CONVERT(decimal(18,6), ISNULL(NULLIF(iu.MultipleToBase, 0), 1)),
        BaseReqQty      = CONVERT(decimal(18,6),
                            ROUND(
                                ISNULL(NULLIF(t.OrdQty, 0), 1)
                                * ISNULL(NULLIF(iu.MultipleToBase, 0), 1)
                                / ISNULL(NULLIF(t.FactorToBase, 0), 1.0),
                                6
                            )
                         ),
        AllocBase       = CONVERT(decimal(18,6), 0),
        AllocQty        = CONVERT(decimal(18,2), 0),
        IsShort         = CONVERT(bit, 0),
        AllocNote       = CONVERT(varchar(200), NULL),
        Processed       = CASE WHEN t.OrdQty < 0 THEN 1 ELSE 0 END,
        IsCredit        = CASE WHEN t.OrdQty < 0 THEN 1 ELSE 0 END,
        FinalNotes      = CONVERT(varchar(1000), NULL)
    INTO #Rows
    FROM dbo.TempSales t
    LEFT JOIN dbo.ItemUnit iu
        ON iu.ItemUnitId = t.ItemUnitId
    WHERE t.PayeeId  = @PayeeId
      AND t.EmpId    = @EmpId
      AND t.SalesId  = CASE WHEN @IsEdit = 0 THEN 0 ELSE @SalesId END
      AND t.IsStrike = 0
      AND t.ItemId IS NOT NULL;

    ----------------------------------------------------------------------
    -- 2) Per-item available stock in BASE units
    ----------------------------------------------------------------------
    DECLARE @Stock TABLE
    (
        ItemId INT PRIMARY KEY,
        RemainingBase decimal(18,6)
    );

    INSERT INTO @Stock (ItemId, RemainingBase)
    SELECT
        r.ItemId,
        RemainingBase = CONVERT(decimal(18,6),
            CASE
                WHEN ISNULL(i.LCloseQty, 0) < 0 THEN 0
                ELSE ISNULL(i.LCloseQty, 0)
            END
            +
            CASE
                WHEN @IsEdit = 1 THEN
                    ISNULL(
                        (
                            SELECT SUM(
                                ISNULL(
                                    sd.BaseHoldQty,
                                    -- 2026-07-03: consume the stored base qty instead of recomputing from the
                                    -- FactorToBase snapshot (same formula was used to set BaseShipQty at insert). Prior line:
                                    -- ROUND(ISNULL(sd.ShipQty, 0) / NULLIF(sd.FactorToBase, 0), 6)
                                    sd.BaseShipQty
                                )
                            )
                            FROM dbo.SalesDetail sd
                            WHERE sd.SalesId = @SalesId
                              AND sd.ItemId = r.ItemId
                        ),
                        0
                    )
                ELSE 0
            END
        )
    FROM #Rows r
    INNER JOIN dbo.Item i
        ON i.ItemId = r.ItemId
    GROUP BY r.ItemId, i.LCloseQty;

    ----------------------------------------------------------------------
    -- 3) FIFO allocation loop ordered by TempSalesId
    ----------------------------------------------------------------------
    DECLARE
        @TempSalesId INT,
        @ItemId INT,
        @BaseReqQty decimal(18,6),
        @RemainBase decimal(18,6),
        @AllocBase decimal(18,6),
        @Factor decimal(18,6),
        @Multiple decimal(18,6);

    WHILE EXISTS (SELECT 1 FROM #Rows WHERE Processed = 0)
    BEGIN
        SELECT TOP (1)
            @TempSalesId = TempSalesId,
            @ItemId      = ItemId,
            @BaseReqQty  = BaseReqQty,
            @Factor      = FactorToBase,
            @Multiple    = MultipleToBase
        FROM #Rows
        WHERE Processed = 0
        ORDER BY TempSalesId;

        SELECT @RemainBase = s.RemainingBase
        FROM @Stock s
        WHERE s.ItemId = @ItemId;

        SET @RemainBase = ISNULL(@RemainBase, 0);

        SET @AllocBase =
            CASE
                WHEN @RemainBase <= 0 THEN 0
                WHEN @BaseReqQty <= @RemainBase THEN @BaseReqQty
                ELSE @RemainBase
            END;

        -- [2026-07-20] Whole-unit rule: never allocate a fraction of the line's unit.
        -- whole units = base * Factor / Multiple; back to base = whole * Multiple / Factor.
        -- ROUND(,4) before FLOOR: 6dp base snapshots make a whole ÷12 unit 0.999996, not 1.
        SET @AllocBase = ROUND(FLOOR(ROUND(@AllocBase * @Factor / @Multiple, 4)) * @Multiple / @Factor, 6);

        UPDATE #Rows
        SET AllocBase = @AllocBase,
            Processed = 1
        WHERE TempSalesId = @TempSalesId;

        UPDATE s
        SET s.RemainingBase =
            CASE
                WHEN @RemainBase - @AllocBase < 0 THEN 0
                ELSE @RemainBase - @AllocBase
            END
        FROM @Stock s
        WHERE s.ItemId = @ItemId;
    END

    ----------------------------------------------------------------------
    -- 3.5) Prepare final values for writeback
    ----------------------------------------------------------------------
    UPDATE r
    SET
        -- [2026-07-20] full ratio: unit qty = base * Factor / Multiple
        r.AllocQty = ROUND(r.AllocBase * r.FactorToBase / r.MultipleToBase, 2),
        r.IsShort  = CASE WHEN r.AllocBase < r.BaseReqQty THEN 1 ELSE 0 END,
        r.AllocNote = CONCAT(
            '[ALLOC: ',
            CAST(CAST(r.AllocBase AS decimal(18,2)) AS varchar(20)),
            ' out of ',
            CAST(CAST(r.BaseReqQty AS decimal(18,2)) AS varchar(20)),
            ' in stock]'
        ),
        r.FinalNotes =
            LTRIM(RTRIM(
                CASE
                    WHEN CASE WHEN r.AllocBase < r.BaseReqQty THEN 1 ELSE 0 END = 1 THEN
                        CASE
                            WHEN t.Notes LIKE '%[ALLOC:%]%' THEN
                                REPLACE(
                                    t.Notes,
                                    SUBSTRING(
                                        t.Notes,
                                        CHARINDEX('[ALLOC:', t.Notes),
                                        CHARINDEX(']', t.Notes, CHARINDEX('[ALLOC:', t.Notes))
                                            - CHARINDEX('[ALLOC:', t.Notes) + 1
                                    ),
                                    CONCAT(
                                        '[ALLOC: ',
                                        CAST(CAST(r.AllocBase AS decimal(18,2)) AS varchar(20)),
                                        ' out of ',
                                        CAST(CAST(r.BaseReqQty AS decimal(18,2)) AS varchar(20)),
                                        ' in stock]'
                                    )
                                )
                            WHEN NULLIF(LTRIM(RTRIM(t.Notes)), '') IS NOT NULL THEN
                                CONCAT(
                                    LTRIM(RTRIM(t.Notes)),
                                    ' ',
                                    CONCAT(
                                        '[ALLOC: ',
                                        CAST(CAST(r.AllocBase AS decimal(18,2)) AS varchar(20)),
                                        ' out of ',
                                        CAST(CAST(r.BaseReqQty AS decimal(18,2)) AS varchar(20)),
                                        ' in stock]'
                                    )
                                )
                            ELSE
                                CONCAT(
                                    '[ALLOC: ',
                                    CAST(CAST(r.AllocBase AS decimal(18,2)) AS varchar(20)),
                                    ' out of ',
                                    CAST(CAST(r.BaseReqQty AS decimal(18,2)) AS varchar(20)),
                                    ' in stock]'
                                )
                        END
                    ELSE
                        REPLACE(
                            REPLACE(
                                LTRIM(RTRIM(ISNULL(t.Notes, ''))),
                                CASE
                                    WHEN t.Notes LIKE '%[ALLOC:%]%' THEN
                                        SUBSTRING(
                                            t.Notes,
                                            CHARINDEX('[ALLOC:', t.Notes),
                                            CHARINDEX(']', t.Notes, CHARINDEX('[ALLOC:', t.Notes))
                                                - CHARINDEX('[ALLOC:', t.Notes) + 1
                                        )
                                    ELSE
                                        ''
                                END,
                                ''
                            ),
                            '  ',
                            ' '
                        )
                END
            ))
    FROM #Rows r
    INNER JOIN dbo.TempSales t
        ON t.TempSalesId = r.TempSalesId
    WHERE r.IsCredit = 0;

    ----------------------------------------------------------------------
    -- 4) Write back to TempSales
    ----------------------------------------------------------------------
    UPDATE t
    SET
        t.BaseOrdQty  = r.AllocBase,
        t.BaseHoldQty = r.AllocBase,

        t.OrdQty = r.AllocQty,

        t.ShipQty =
            CASE
                WHEN t.IsOut = 1 THEN 0
                WHEN t.IsFree = 1 THEN r.AllocQty
                WHEN t.IsCRCG = 1 THEN 0
                ELSE r.AllocQty
            END,

        t.BillQty =
            CASE
                WHEN t.IsOut = 1 THEN 0
                WHEN t.IsFree = 1 THEN 0
                WHEN t.IsCRCG = 1 THEN r.AllocQty
                ELSE r.AllocQty
            END,

        t.Notes = r.FinalNotes
    FROM dbo.TempSales t
    INNER JOIN #Rows r
        ON r.TempSalesId = t.TempSalesId
    WHERE r.IsCredit = 0;

    ----------------------------------------------------------------------
    -- 5) Recalculate ExtTotal if needed
    ----------------------------------------------------------------------
    -- UPDATE dbo.TempSales
    -- SET ExtTotal =
    --     CASE
    --         WHEN IsFree = 1 OR IsOut = 1 THEN 0
    --         ELSE ROUND(OrdQty * UnitPrice, 2)
    --     END
    -- WHERE PayeeId = @PayeeId
    --   AND EmpId   = @EmpId
    --   AND SalesId = CASE WHEN @IsEdit = 0 THEN 0 ELSE @SalesId END;

    DROP TABLE #Rows;
END
GO
