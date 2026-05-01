-- ============================================================
-- Shipment_Allocation Phase 1: New Methods + Refresh Volume
-- Deploy script — run on KLS_Latest
-- ============================================================
-- Step 1: Rename existing SPs to _prev (for rollback)
-- Step 2: Create new SPs with CREATE OR ALTER
-- ============================================================

-- Step 1: Preserve originals for rollback
IF OBJECT_ID('dbo.Shipment_Allocation_prev') IS NULL
    EXEC sp_rename 'Shipment_Allocation', 'Shipment_Allocation_prev';

IF OBJECT_ID('dbo.Purchase_Allocation_prev') IS NULL
    EXEC sp_rename 'Purchase_Allocation', 'Purchase_Allocation_prev';
GO

-- Step 2: Create new Shipment_Allocation
CREATE OR ALTER PROCEDURE [dbo].[Shipment_Allocation]
    @PurchaseId     INT,
    @AllocationType VARCHAR(20) = 'BY_VOLUME',
    @RefreshVolume  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StageId INT;

    SELECT @StageId = StageId
    FROM dbo.Purchase
    WHERE PurchaseId = @PurchaseId;

    IF @StageId <> 6
        RETURN;

    BEGIN TRY
        BEGIN TRAN;

        IF @RefreshVolume = 1
        BEGIN
            UPDATE pd
            SET    pd.ItemVolume = ISNULL(i.CaseVolumeInCubicMeter, pd.ItemVolume)
            FROM   dbo.PurchaseDetail pd
            JOIN   dbo.Item i ON pd.ItemId = i.ItemId
            WHERE  pd.PurchaseId = @PurchaseId
              AND  pd.ItemId IS NOT NULL
              AND  i.CaseVolumeInCubicMeter IS NOT NULL;
        END

        UPDATE pd
        SET    pd.LandedCost = 0
        FROM   dbo.PurchaseDetail pd
        WHERE  pd.PurchaseId = @PurchaseId
          AND  pd.ItemId IS NOT NULL;

        IF OBJECT_ID('tempdb..#Shipments') IS NOT NULL DROP TABLE #Shipments;

        SELECT DISTINCT sp.ShipmentId
        INTO   #Shipments
        FROM   dbo.ShipmentPurchase sp
        WHERE  sp.PurchaseId = @PurchaseId;

        DECLARE @InlineFreightAccountId INT;
        DECLARE @InlineFreightTotal DECIMAL(18,2) = 0;

        SELECT TOP (1) @InlineFreightAccountId = a.AccountId
        FROM   dbo.Account a
        WHERE  a.AccountCode = '@INVC';

        IF NOT EXISTS (SELECT 1 FROM #Shipments)
        BEGIN
            IF @InlineFreightAccountId IS NOT NULL
            BEGIN
                SELECT @InlineFreightTotal =
                    ROUND(SUM(ISNULL(pd.BaseFinalQty, 0) * ISNULL(pd.FinalPrice, 0)), 2)
                FROM   dbo.PurchaseDetail pd
                WHERE  pd.PurchaseId = @PurchaseId
                  AND  pd.ItemId IS NULL
                  AND  pd.AccountId = @InlineFreightAccountId;
            END

            IF ISNULL(@InlineFreightTotal, 0) = 0
            BEGIN
                COMMIT TRAN;
                RETURN;
            END

            IF OBJECT_ID('tempdb..#LinesInlineOnly') IS NOT NULL DROP TABLE #LinesInlineOnly;

            SELECT
                pd.PurchaseDetailId,
                LineBasis =
                    CASE
                        WHEN @AllocationType = 'BY_VOLUME'
                            THEN ISNULL(pd.BaseFinalQty, 0) * ISNULL(pd.ItemVolume, 0)
                        WHEN @AllocationType = 'BY_WEIGHT'
                            THEN ISNULL(pd.BaseFinalQty, 0) * ISNULL(i.CaseWeight, 0)
                        WHEN @AllocationType = 'BY_QUANTITY'
                            THEN ISNULL(pd.BaseFinalQty, 0)
                        ELSE
                            ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0)
                    END
            INTO   #LinesInlineOnly
            FROM   dbo.PurchaseDetail pd
            JOIN   dbo.Item i ON pd.ItemId = i.ItemId
            WHERE  pd.PurchaseId = @PurchaseId
              AND  i.ItemType = 'Inventory'
              AND  pd.ItemId IS NOT NULL;

            DELETE FROM #LinesInlineOnly WHERE ISNULL(LineBasis, 0) <= 0;

            DECLARE @TotalBasisInline DECIMAL(18,2) = 0;
            SELECT @TotalBasisInline = SUM(LineBasis) FROM #LinesInlineOnly;

            IF ISNULL(@TotalBasisInline, 0) = 0
            BEGIN
                COMMIT TRAN;
                RETURN;
            END

            ;WITH Base AS (
                SELECT
                    PurchaseDetailId,
                    LineBasis,
                    RoundedAlloc = ROUND(@InlineFreightTotal * (LineBasis / NULLIF(@TotalBasisInline, 0.0)), 2),
                    rn           = ROW_NUMBER() OVER (ORDER BY LineBasis DESC, PurchaseDetailId ASC)
                FROM #LinesInlineOnly
            ),
            SumRounded AS (
                SELECT SUM(RoundedAlloc) AS SumRounded FROM Base
            )
            UPDATE pd
            SET    pd.LandedCost =
                       CASE
                           WHEN b.rn = 1 THEN b.RoundedAlloc + (@InlineFreightTotal - sr.SumRounded)
                           ELSE b.RoundedAlloc
                       END
            FROM   dbo.PurchaseDetail pd
            JOIN   Base b ON b.PurchaseDetailId = pd.PurchaseDetailId
            CROSS JOIN SumRounded sr;

            COMMIT TRAN;
            RETURN;
        END

        IF OBJECT_ID('tempdb..#ImpactedPurchases') IS NOT NULL DROP TABLE #ImpactedPurchases;

        SELECT DISTINCT sp.PurchaseId
        INTO   #ImpactedPurchases
        FROM   dbo.ShipmentPurchase sp
        JOIN   #Shipments s ON s.ShipmentId = sp.ShipmentId;

        IF OBJECT_ID('tempdb..#Lines') IS NOT NULL DROP TABLE #Lines;

        SELECT
            pd.PurchaseDetailId,
            pd.PurchaseId,
            LineValue  = ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0),
            LineVolume = ISNULL(pd.BaseFinalQty, 0) * ISNULL(pd.ItemVolume, 0),
            DutyWeight = (ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0))
                         * (ISNULL(pd.CustomDutyRate, 0) + ISNULL(pd.TariffPercent, 0)),
            LineWeight = ISNULL(pd.BaseFinalQty, 0) * ISNULL(i.CaseWeight, 0),
            LineQty    = ISNULL(pd.BaseFinalQty, 0)
        INTO   #Lines
        FROM   dbo.PurchaseDetail pd
        JOIN   #ImpactedPurchases ip ON ip.PurchaseId = pd.PurchaseId
        JOIN   dbo.Item i ON pd.ItemId = i.ItemId
        WHERE  i.ItemType = 'Inventory'
          AND  pd.ItemId IS NOT NULL;

        DELETE FROM #Lines
        WHERE  ISNULL(LineValue, 0)  <= 0
          AND  ISNULL(LineVolume, 0) <= 0
          AND  ISNULL(DutyWeight, 0) <= 0
          AND  ISNULL(LineWeight, 0) <= 0
          AND  ISNULL(LineQty, 0)    <= 0;

        IF OBJECT_ID('tempdb..#InlineFreight') IS NOT NULL DROP TABLE #InlineFreight;

        DELETE sc
        FROM   dbo.ShipmentCharge sc
        JOIN   #Shipments s ON s.ShipmentId = sc.ShipmentId
        WHERE  sc.ChargeType = 'Freight'
          AND  sc.Notes = 'Inline Freight';

        SELECT
            pd.PurchaseId,
            FreightAmount = SUM(ISNULL(pd.BaseFinalQty, 0) * ISNULL(pd.FinalPrice, 0))
        INTO   #InlineFreight
        FROM   dbo.PurchaseDetail pd
        JOIN   #ImpactedPurchases ip ON ip.PurchaseId = pd.PurchaseId
        WHERE  pd.ItemId IS NULL
          AND  pd.AccountId = @InlineFreightAccountId
        GROUP BY pd.PurchaseId;

        DELETE FROM #InlineFreight WHERE ISNULL(FreightAmount, 0) <= 0;

        IF EXISTS (SELECT 1 FROM #InlineFreight)
        BEGIN
            IF OBJECT_ID('tempdb..#InlineFreightPerShipment') IS NOT NULL DROP TABLE #InlineFreightPerShipment;

            ;WITH ShipCount AS (
                SELECT sp.PurchaseId, Cnt = COUNT(DISTINCT sp.ShipmentId)
                FROM   dbo.ShipmentPurchase sp
                JOIN   #Shipments s ON s.ShipmentId = sp.ShipmentId
                GROUP BY sp.PurchaseId
            )
            SELECT
                sp.ShipmentId,
                ChargeAmount = ROUND(f.FreightAmount / NULLIF(sc.Cnt, 0), 2)
            INTO   #InlineFreightPerShipment
            FROM   #InlineFreight f
            JOIN   ShipCount sc ON sc.PurchaseId = f.PurchaseId
            JOIN   dbo.ShipmentPurchase sp ON sp.PurchaseId = f.PurchaseId
            JOIN   #Shipments s ON s.ShipmentId = sp.ShipmentId;

            DELETE FROM #InlineFreightPerShipment WHERE ISNULL(ChargeAmount, 0) = 0;

            INSERT INTO dbo.ShipmentCharge (ShipmentId, ChargeType, ChargeAmount, Notes, AllocationMethod)
            SELECT ShipmentId, 'Freight', ChargeAmount, 'Inline Freight', 'BY_VALUE'
            FROM   #InlineFreightPerShipment;
        END

        IF OBJECT_ID('tempdb..#Charges') IS NOT NULL DROP TABLE #Charges;

        SELECT
            sc.ChargeId,
            sc.ShipmentId,
            sc.ChargeType,
            sc.AllocationMethod,
            ChargeAmount = ISNULL(sc.ChargeAmount, 0.00)
        INTO   #Charges
        FROM   dbo.ShipmentCharge sc
        JOIN   #Shipments s ON s.ShipmentId = sc.ShipmentId
        WHERE  ISNULL(sc.ChargeAmount, 0) <> 0;

        IF NOT EXISTS (SELECT 1 FROM #Charges)
        BEGIN
            DELETE sa
            FROM   dbo.ShipmentAllocation sa
            JOIN   dbo.ShipmentCharge sc ON sc.ChargeId = sa.ChargeId
            JOIN   #Shipments s ON s.ShipmentId = sc.ShipmentId;

            UPDATE pd
            SET    pd.LandedCost = ISNULL(x.SumAllocated, 0.00)
            FROM   dbo.PurchaseDetail pd
            JOIN   #ImpactedPurchases ip ON ip.PurchaseId = pd.PurchaseId
            OUTER APPLY (
                SELECT SUM(sa.AllocatedAmount) AS SumAllocated
                FROM   dbo.ShipmentAllocation sa
                WHERE  sa.PurchaseDetailId = pd.PurchaseDetailId
            ) x;

            COMMIT TRAN;
            RETURN;
        END

        DELETE sa
        FROM   dbo.ShipmentAllocation sa
        JOIN   #Charges c ON c.ChargeId = sa.ChargeId;

        ;WITH ShipTotals AS (
            SELECT
                sp.ShipmentId,
                TotalValue   = SUM(l.LineValue),
                TotalVolume  = SUM(l.LineVolume),
                TotalDutyWgt = SUM(l.DutyWeight),
                TotalWeight  = SUM(l.LineWeight),
                TotalQty     = SUM(l.LineQty)
            FROM   #Shipments sp
            JOIN   dbo.ShipmentPurchase spx ON spx.ShipmentId = sp.ShipmentId
            JOIN   #Lines l ON l.PurchaseId = spx.PurchaseId
            GROUP BY sp.ShipmentId
        ),
        Base AS (
            SELECT
                c.ChargeId,
                c.ShipmentId,
                c.ChargeType,
                c.AllocationMethod,
                l.PurchaseDetailId,
                c.ChargeAmount,

                LineBasis =
                    CASE
                        WHEN c.AllocationMethod IN ('BY_DUTY', 'BY_TARIFF') AND ISNULL(st.TotalDutyWgt, 0) > 0 THEN l.DutyWeight
                        WHEN c.AllocationMethod = 'BY_VOLUME'               AND ISNULL(st.TotalVolume, 0)  > 0 THEN l.LineVolume
                        WHEN c.AllocationMethod = 'BY_WEIGHT'               AND ISNULL(st.TotalWeight, 0)  > 0 THEN l.LineWeight
                        WHEN c.AllocationMethod = 'BY_QUANTITY'              AND ISNULL(st.TotalQty, 0)    > 0  THEN l.LineQty
                        ELSE l.LineValue
                    END,

                TotalBasis =
                    CASE
                        WHEN c.AllocationMethod IN ('BY_DUTY', 'BY_TARIFF') AND ISNULL(st.TotalDutyWgt, 0) > 0 THEN st.TotalDutyWgt
                        WHEN c.AllocationMethod = 'BY_VOLUME'               AND ISNULL(st.TotalVolume, 0)  > 0 THEN st.TotalVolume
                        WHEN c.AllocationMethod = 'BY_WEIGHT'               AND ISNULL(st.TotalWeight, 0)  > 0 THEN st.TotalWeight
                        WHEN c.AllocationMethod = 'BY_QUANTITY'              AND ISNULL(st.TotalQty, 0)    > 0  THEN st.TotalQty
                        ELSE st.TotalValue
                    END,

                UsedMethod =
                    CASE
                        WHEN c.AllocationMethod = 'BY_DUTY'    AND ISNULL(st.TotalDutyWgt, 0) > 0 THEN 'BY_DUTY'
                        WHEN c.AllocationMethod = 'BY_TARIFF'  AND ISNULL(st.TotalDutyWgt, 0) > 0 THEN 'BY_TARIFF'
                        WHEN c.AllocationMethod = 'BY_VOLUME'  AND ISNULL(st.TotalVolume, 0)  > 0 THEN 'BY_VOLUME'
                        WHEN c.AllocationMethod = 'BY_WEIGHT'  AND ISNULL(st.TotalWeight, 0)  > 0 THEN 'BY_WEIGHT'
                        WHEN c.AllocationMethod = 'BY_QUANTITY' AND ISNULL(st.TotalQty, 0)    > 0  THEN 'BY_QUANTITY'
                        WHEN c.AllocationMethod IN ('BY_DUTY', 'BY_TARIFF', 'BY_VOLUME', 'BY_WEIGHT', 'BY_PALLET', 'BY_QUANTITY')
                            THEN 'BY_VALUE_FALLBACK'
                        ELSE 'BY_VALUE'
                    END,

                rn = ROW_NUMBER() OVER (
                    PARTITION BY c.ChargeId
                    ORDER BY
                        CASE
                            WHEN c.AllocationMethod IN ('BY_DUTY', 'BY_TARIFF') AND ISNULL(st.TotalDutyWgt, 0) > 0 THEN l.DutyWeight
                            WHEN c.AllocationMethod = 'BY_VOLUME'               AND ISNULL(st.TotalVolume, 0)  > 0 THEN l.LineVolume
                            WHEN c.AllocationMethod = 'BY_WEIGHT'               AND ISNULL(st.TotalWeight, 0)  > 0 THEN l.LineWeight
                            WHEN c.AllocationMethod = 'BY_QUANTITY'              AND ISNULL(st.TotalQty, 0)    > 0  THEN l.LineQty
                            ELSE l.LineValue
                        END DESC,
                        l.PurchaseDetailId ASC
                )

            FROM   #Charges c
            JOIN   ShipTotals st ON st.ShipmentId = c.ShipmentId
            JOIN   dbo.ShipmentPurchase sp ON sp.ShipmentId = c.ShipmentId
            JOIN   #Lines l ON l.PurchaseId = sp.PurchaseId
            WHERE  ISNULL(st.TotalValue, 0)   > 0
               OR  ISNULL(st.TotalVolume, 0)  > 0
               OR  ISNULL(st.TotalDutyWgt, 0) > 0
               OR  ISNULL(st.TotalWeight, 0)  > 0
               OR  ISNULL(st.TotalQty, 0)     > 0
        ),
        Base2 AS (
            SELECT
                ChargeId,
                PurchaseDetailId,
                ChargeAmount,
                UsedMethod,
                rn,
                RoundedAlloc = ROUND(ChargeAmount * (LineBasis / NULLIF(TotalBasis, 0.0)), 2)
            FROM   Base
            WHERE  ISNULL(TotalBasis, 0) > 0
        ),
        SumRounded AS (
            SELECT ChargeId, SumRounded = SUM(RoundedAlloc)
            FROM   Base2
            GROUP BY ChargeId
        )
        INSERT INTO dbo.ShipmentAllocation
            (ChargeId, PurchaseDetailId, AllocatedAmount, AllocationMethod, CreatedAt)
        SELECT
            b.ChargeId,
            b.PurchaseDetailId,
            CASE
                WHEN b.rn = 1 THEN b.RoundedAlloc + (b.ChargeAmount - sr.SumRounded)
                ELSE b.RoundedAlloc
            END,
            b.UsedMethod,
            GETUTCDATE()
        FROM   Base2 b
        JOIN   SumRounded sr ON sr.ChargeId = b.ChargeId
        ORDER BY b.ChargeId, b.PurchaseDetailId;

        UPDATE pd
        SET    pd.LandedCost = ISNULL(x.SumAllocated, 0.00)
        FROM   dbo.PurchaseDetail pd
        JOIN   #ImpactedPurchases ip ON ip.PurchaseId = pd.PurchaseId
        OUTER APPLY (
            SELECT SUM(sa.AllocatedAmount) AS SumAllocated
            FROM   dbo.ShipmentAllocation sa
            WHERE  sa.PurchaseDetailId = pd.PurchaseDetailId
        ) x;

        COMMIT TRAN;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        DECLARE
            @ErrMsg      NVARCHAR(4000) = ERROR_MESSAGE(),
            @ErrNum      INT            = ERROR_NUMBER(),
            @ErrState    INT            = ERROR_STATE(),
            @ErrSeverity INT            = ERROR_SEVERITY(),
            @ErrLine     INT            = ERROR_LINE(),
            @ErrProc     NVARCHAR(200)  = ERROR_PROCEDURE();

        RAISERROR(
            'Shipment_Allocation failed. Proc=%s Line=%d Error=%d State=%d Msg=%s',
            @ErrSeverity, 1,
            @ErrProc, @ErrLine, @ErrNum, @ErrState, @ErrMsg
        );
    END CATCH
END
GO

-- Step 3: Create new Purchase_Allocation wrapper
CREATE OR ALTER PROCEDURE [dbo].[Purchase_Allocation]
    @PurchaseId    INT,
    @RefreshVolume BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.Shipment_Allocation
        @PurchaseId     = @PurchaseId,
        @AllocationType = 'BY_VOLUME',
        @RefreshVolume  = @RefreshVolume;

    EXEC dbo.Shipment_AllocationInventoryClear @PurchaseId;

    DECLARE @ShipmentId INT;

    DECLARE shipment_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT ShipmentId
    FROM   dbo.ShipmentPurchase
    WHERE  PurchaseId = @PurchaseId;

    OPEN shipment_cursor;
    FETCH NEXT FROM shipment_cursor INTO @ShipmentId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.Shipment_GenerateBill @ShipmentId;
        FETCH NEXT FROM shipment_cursor INTO @ShipmentId;
    END

    CLOSE shipment_cursor;
    DEALLOCATE shipment_cursor;
END
GO
