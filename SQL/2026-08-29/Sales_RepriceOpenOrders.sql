SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================================
-- 2026-08-29  Sales_RepriceOpenOrders  (plan-reprice-open-orders-v1, slice 3)
--
-- Re-prices open sales orders that were flagged IsPricePending at posting (orders
-- entered on the price-update day before the weekly cost apply ran). Replaces the
-- MGP Update_RePriceOnSales, but rewrites nothing directly: every order goes through
-- the same two SPs the edit screen uses, so journal, ExtTotal, header totals,
-- RecalculationLog and Sales_CalcTotal are all handled by existing, proven code:
--     Sales_Inject  -> load order into TempSales (work EmpId = -1)
--     set UnitPrice + ChangeStatus = 'U' on the lines that change
--     Sales_PartialUpdate -> posts the change, cleans TempSales
--
-- Skipped (reported, not repriced): stage <> 0, locked, drop-ship, CM/DM, ship date
-- passed, orders with promotion lines (promo re-sync lives in C#), orders another
-- user currently has in TempSales. One order failing does not stop the rest.
-- Audit: SalesReprice (run) + SalesRepriceDetail (old/new price per line).
--
-- Work EmpId is ALWAYS -1: Sales_Inject deletes that emp's TempSales rows for the
-- order, so a real user's id must never be used here. @EmpId is audit only.
--
-- EXEC dbo.Sales_RepriceOpenOrders @TriggeredBy = 'MANUAL', @EmpId = NULL, @ApplyId = NULL, @SalesId = NULL,
--      @RepriceId = @r OUTPUT, @OrderCount = @o OUTPUT, @LineCount = @l OUTPUT, @SkippedCount = @s OUTPUT
-- Result set: skipped orders (SalesId, SalesNumber, StageId, Reason).
-- ============================================================================
CREATE OR ALTER PROCEDURE [dbo].[Sales_RepriceOpenOrders]
    @TriggeredBy  NVARCHAR(20),
    @EmpId        INT = NULL,
    @ApplyId      INT = NULL,
    @SalesId      INT = NULL,
    @RepriceId    INT OUTPUT,
    @OrderCount   INT OUTPUT,
    @LineCount    INT OUTPUT,
    @SkippedCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @TriggeredBy NOT IN ('SCHEDULER', 'MANUAL')
        THROW 51070, 'TriggeredBy must be SCHEDULER or MANUAL.', 1;

    DECLARE @WorkEmpId  INT  = -1;
    DECLARE @Today      DATE = CAST(GETDATE() AS DATE);
    DECLARE @ErrorCount INT  = 0;

    SET @OrderCount = 0; SET @LineCount = 0; SET @SkippedCount = 0;

    -- Section 1: candidates = flagged orders (or the one order asked for).
    CREATE TABLE #Cand (
        SalesId     INT PRIMARY KEY,
        SalesNumber INT,
        PayeeId     INT,
        StageId     INT,
        Reason      NVARCHAR(200) NULL,
        Done        BIT NOT NULL DEFAULT 0
    );

    INSERT INTO #Cand (SalesId, SalesNumber, PayeeId, StageId, Reason)
    SELECT s.SalesId, s.SalesNumber, s.ShipId, s.StageId,
           CASE
               WHEN s.StageId <> 0            THEN 'Pick ticket or invoice already printed (stage ' + CONVERT(NVARCHAR(10), s.StageId) + ')'
               WHEN s.IsLocked = 1            THEN 'Order is locked'
               WHEN s.IsDropShip = 1          THEN 'Drop-ship order'
               WHEN s.DocType IN ('CM', 'DM') THEN 'Credit/debit memo'
               WHEN s.ShipDate < @Today       THEN 'Ship date already passed'
               WHEN EXISTS (SELECT 1 FROM dbo.SalesDetail d
                            WHERE d.SalesId = s.SalesId
                              AND (d.IsSystemManaged = 1 OR ISNULL(d.CartLineType, 'MAIN') <> 'MAIN'))
                                              THEN 'Has promotion lines - reprice manually'
               WHEN EXISTS (SELECT 1 FROM dbo.TempSales t
                            WHERE t.SalesId = s.SalesId AND t.EmpId <> @WorkEmpId)
                                              THEN 'Being edited by EmpId ' + CONVERT(NVARCHAR(10),
                                                   (SELECT TOP (1) t.EmpId FROM dbo.TempSales t WHERE t.SalesId = s.SalesId AND t.EmpId <> @WorkEmpId))
               ELSE NULL
           END
    FROM dbo.Sales s
    WHERE (@SalesId IS NULL AND s.IsPricePending = 1)
       OR (@SalesId IS NOT NULL AND s.SalesId = @SalesId);

    -- Section 2: audit header first so a partial run is still visible.
    INSERT INTO dbo.SalesReprice (ApplyId, TriggeredBy, EmpId)
    VALUES (@ApplyId, @TriggeredBy, @EmpId);
    SET @RepriceId = SCOPE_IDENTITY();

    SELECT @SkippedCount = COUNT(*) FROM #Cand WHERE Reason IS NOT NULL;
    UPDATE #Cand SET Done = 1 WHERE Reason IS NOT NULL;

    -- Section 3: one order at a time, each in its own try so one failure cannot stop the run.
    DECLARE @Sid INT, @PayeeId INT, @Changed INT, @Msg NVARCHAR(2048);

    DECLARE @New TABLE (
        TempSalesId   INT,
        SalesDetailId INT,
        OldPrice      DECIMAL(18,4),
        NewPrice      DECIMAL(18,4)
    );

    WHILE EXISTS (SELECT 1 FROM #Cand WHERE Done = 0)
    BEGIN
        -- reset per-iteration state (stale values must never target the wrong order)
        SET @Sid = NULL; SET @PayeeId = NULL; SET @Changed = 0; SET @Msg = NULL;
        DELETE FROM @New;

        SELECT TOP (1) @Sid = SalesId, @PayeeId = PayeeId FROM #Cand WHERE Done = 0 ORDER BY SalesId;

        BEGIN TRY
            -- 3a: load the order into the work cart (deletes any prior EmpId -1 rows for it)
            EXEC dbo.Sales_Inject @EmpId = @WorkEmpId, @SalesId = @Sid;

            -- 3b: new price per eligible line: item lines, not rep-priced, MAIN, not system.
            --     Fn_GetPrice = the same function order entry uses (customer markup / quotes / round-up).
            --     A NULL/0 price never overwrites a real one (D3).
            INSERT INTO @New (TempSalesId, SalesDetailId, OldPrice, NewPrice)
            SELECT ts.TempSalesId, ts.SalesDetailId, ts.UnitPrice, p.Price
            FROM dbo.TempSales ts
            OUTER APPLY (SELECT TOP (1) f.Price
                         FROM dbo.Fn_GetPrice(@PayeeId, ts.ItemId, ts.ItemUnitId) f) p
            WHERE ts.EmpId = @WorkEmpId AND ts.SalesId = @Sid AND ts.PayeeId = @PayeeId
              AND ts.LineType = 'I'
              AND ts.IsManualPrice = 0
              AND ts.CartLineType = 'MAIN'
              AND ts.IsSystemManaged = 0
              AND ts.SalesDetailId IS NOT NULL
              AND ISNULL(p.Price, 0) > 0
              AND p.Price <> ts.UnitPrice;

            SET @Changed = @@ROWCOUNT;

            IF @Changed = 0
            BEGIN
                -- nothing to change: drop the work cart, clear the flag below
                DELETE FROM dbo.TempSales WHERE EmpId = @WorkEmpId AND SalesId = @Sid AND PayeeId = @PayeeId;
            END
            ELSE
            BEGIN
                INSERT INTO dbo.SalesRepriceDetail (RepriceId, SalesId, SalesDetailId, OldPrice, NewPrice)
                SELECT @RepriceId, @Sid, SalesDetailId, OldPrice, NewPrice FROM @New;

                UPDATE ts
                SET ts.UnitPrice = n.NewPrice,
                    ts.ChangeStatus = 'U'
                FROM dbo.TempSales ts
                INNER JOIN @New n ON n.TempSalesId = ts.TempSalesId;

                -- 3c: post through the edit-screen path (journal, ExtTotal, totals,
                --     RecalculationLog, TempSales cleanup, Sales_CalcTotal)
                EXEC dbo.Sales_PartialUpdate @SalesId = @Sid, @EmpId = @WorkEmpId;

                SET @LineCount = @LineCount + @Changed;
            END

            UPDATE dbo.Sales SET IsPricePending = 0 WHERE SalesId = @Sid;

            SET @OrderCount = @OrderCount + 1;
            UPDATE #Cand SET Done = 1 WHERE SalesId = @Sid;
        END TRY
        BEGIN CATCH
            SET @Msg = ERROR_MESSAGE();

            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

            -- never leave a work cart behind
            DELETE FROM dbo.TempSales WHERE EmpId = @WorkEmpId AND SalesId = @Sid;

            SET @ErrorCount = @ErrorCount + 1;
            UPDATE #Cand SET Done = 1, Reason = 'Error: ' + LEFT(@Msg, 190) WHERE SalesId = @Sid;
        END CATCH
    END

    -- Section 4: close the audit row.
    UPDATE dbo.SalesReprice
    SET OrderCount   = @OrderCount,
        LineCount    = @LineCount,
        SkippedCount = @SkippedCount,
        ErrorCount   = @ErrorCount
    WHERE RepriceId = @RepriceId;

    -- Section 5: skipped + errored orders for the office (Q4).
    SELECT SalesId, SalesNumber, StageId, Reason
    FROM #Cand
    WHERE Reason IS NOT NULL
    ORDER BY SalesNumber;

    DROP TABLE #Cand;
END
GO
