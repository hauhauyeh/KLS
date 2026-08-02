-- SCR_B_GUARD_20260710: scope guard so new per-bill charges (ShipmentPurchaseId NOT NULL) are
-- NOT touched by the legacy cross-vendor engine; they are owned by Shipment_AllocateWithinBill.
CREATE   PROCEDURE [dbo].[Shipment_Allocation] -- EXEC Shipment_Allocation @PurchaseId=12164,@AllocationType='BY_VOLUME',@RefreshVolume=0
-- EXEC Shipment_Allocation @PurchaseId=12164,@AllocationType='BY_VOLUME',@RefreshVolume=1
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

    -- Only for Billed stage
    IF @StageId <> 6
        RETURN;

    -- 2026-07-13 DROPSHIP-EXCLUDE old behavior:
    --   Drop-ship bills returned before allocation and cleared LandedCost to 0.
    -- 2026-08-01 DROPSHIP-COGS-ALLOC:
    --   Drop-ship bills now share the same shipment-wide allocation math as normal bills.
    --   Shipment_AllocationInventoryClear routes the allocated drop-ship landed cost to @COGS.

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

        /* Reset landed cost for product lines */
        UPDATE pd
        SET    pd.LandedCost = 0
        FROM   dbo.PurchaseDetail pd
        WHERE  pd.PurchaseId = @PurchaseId
          AND  pd.ItemId IS NOT NULL;

        /* 1) Find all shipments that include this purchase */
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

         /* If no shipment linked, allocate using inline freight only */
        -- NOTE (2026-06-29): the inline-only path below is a single-bill, no-shipment edge case and is
        -- intentionally left WITHOUT the all-or-nothing completeness guard for now (Plan 1 - Section 9 open
        -- item). All real charges flow through the main shipment path further down, which is guarded.
        IF NOT EXISTS (SELECT 1 FROM #Shipments)
        BEGIN
            IF @InlineFreightAccountId IS NOT NULL
            BEGIN
                SELECT @InlineFreightTotal =
                    ROUND(SUM(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0)), 2)
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
                        --WHEN @AllocationType = 'BY_PALLET' AND ISNULL(i.PaletteFactor, 0) > 0
                        --    THEN ISNULL(pd.BaseFinalQty, 0) / i.PaletteFactor
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

        /* 2) Collect all purchases impacted (all purchases inside those shipments) */
        IF OBJECT_ID('tempdb..#ImpactedPurchases') IS NOT NULL DROP TABLE #ImpactedPurchases;

        -- 2026-08-01 DROPSHIP-COGS-ALLOC:
        -- Include billed drop-ship purchases in the shipment-wide basis/write path. The allocation
        -- formula stays shared with normal bills; downstream clearing chooses @INV vs @COGS.
        -- Prior 2026-07-13 DROPSHIP-EXCLUDE filtered them out:
        --   WHERE ISNULL(p.IsDropShip, 0) = 0;
        SELECT DISTINCT sp.PurchaseId
        INTO   #ImpactedPurchases
        FROM   dbo.ShipmentPurchase sp
        JOIN   #Shipments s ON s.ShipmentId = sp.ShipmentId
        JOIN   dbo.Purchase p ON p.PurchaseId = sp.PurchaseId
        WHERE  p.StageId = 6;

        /* 3) Collect all purchase detail lines impacted (item lines only) */
        IF OBJECT_ID('tempdb..#Lines') IS NOT NULL DROP TABLE #Lines;

        SELECT
            pd.PurchaseDetailId,
            pd.PurchaseId,
            LineValue  = ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0),
            LineVolume = ISNULL(pd.BaseFinalQty, 0) * ISNULL(pd.ItemVolume, 0),
            DutyWeight = (ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0))
                         * (ISNULL(pd.CustomDutyRate, 0) + ISNULL(pd.TariffPercent, 0)),
            LineWeight = ISNULL(pd.BaseFinalQty, 0) * ISNULL(i.CaseWeight, 0),
            --LinePallet = CASE
            --                 WHEN ISNULL(i.PaletteFactor, 0) > 0
            --                 THEN ISNULL(pd.BaseFinalQty, 0) / i.PaletteFactor
            --                 ELSE 0
            --             END,
            LineQty    = ISNULL(pd.BaseFinalQty, 0),
            -- 2026-06-29: raw attributes carried so completeness is tested by ATTRIBUTE PRESENCE,
            -- independent of qty/value (a free line with price 0 must NOT count as "missing"). These
            -- feed the *Complete flags in ShipTotals below.
            ItemVolumeRaw    = ISNULL(pd.ItemVolume, 0),
            CaseWeightRaw    = ISNULL(i.CaseWeight, 0),
            DutyRateCombined = ISNULL(pd.CustomDutyRate, 0) + ISNULL(pd.TariffPercent, 0)
        INTO   #Lines
        FROM   dbo.PurchaseDetail pd
        JOIN   #ImpactedPurchases ip ON ip.PurchaseId = pd.PurchaseId
        JOIN   dbo.Item i ON pd.ItemId = i.ItemId
        WHERE  i.ItemType = 'Inventory'
          AND  pd.ItemId IS NOT NULL;

        /* Remove lines that can't be allocated in any basis */
        DELETE FROM #Lines
        WHERE  ISNULL(LineValue, 0)  <= 0
          AND  ISNULL(LineVolume, 0) <= 0
          AND  ISNULL(DutyWeight, 0) <= 0
          AND  ISNULL(LineWeight, 0) <= 0
          --AND  ISNULL(LinePallet, 0) <= 0
          AND  ISNULL(LineQty, 0)    <= 0;

        /* 3A ADD INLINE FREIGHT AS SHIPMENT CHARGE (system) */
        IF OBJECT_ID('tempdb..#InlineFreight') IS NOT NULL DROP TABLE #InlineFreight;

        -- Always remove previous generated inline freight charges
        DELETE sc
        FROM   dbo.ShipmentCharge sc
        JOIN   #Shipments s ON s.ShipmentId = sc.ShipmentId
        WHERE  sc.ChargeType = 'Freight'
          AND  sc.Notes = 'Inline Freight'
          AND  sc.ShipmentPurchaseId IS NULL;   -- SCR_B_GUARD_20260710: legacy scope only

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
            SELECT ifps.ShipmentId, 'Freight', ifps.ChargeAmount, 'Inline Freight', 'BY_VALUE'
            FROM   #InlineFreightPerShipment ifps
            WHERE  NOT EXISTS (SELECT 1 FROM dbo.ShipmentCharge pbc   -- SCR_B_GUARD_20260710: never create legacy inline
                               WHERE pbc.ShipmentId = ifps.ShipmentId --   freight on a shipment that already has per-bill charges
                                 AND pbc.ShipmentPurchaseId IS NOT NULL
                                 AND ISNULL(pbc.ChargeAmount,0) <> 0);
        END

        /* 4) Collect all charges for those shipments */
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
        WHERE  ISNULL(sc.ChargeAmount, 0) <> 0
          AND  sc.ShipmentPurchaseId IS NULL;   -- SCR_B_GUARD_20260710: skip per-bill charges (owned by Shipment_AllocateWithinBill)

        IF NOT EXISTS (SELECT 1 FROM #Charges)
        BEGIN
            DELETE sa
            FROM   dbo.ShipmentAllocation sa
            JOIN   dbo.ShipmentCharge sc ON sc.ChargeId = sa.ChargeId
            JOIN   #Shipments s ON s.ShipmentId = sc.ShipmentId
            WHERE  sc.ShipmentPurchaseId IS NULL;   -- SCR_B_GUARD_20260710: never delete per-bill allocations

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

        /* 5) Delete existing allocations for these charges (rebuild fresh) */
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
                --TotalPallet  = SUM(l.LinePallet),
                TotalQty     = SUM(l.LineQty),
                -- 2026-06-29: all-or-nothing completeness flags, computed at SHIPMENT scope (the scope
                -- the charge is allocated over, so multi-bill shipments are correct - a sibling bill's
                -- missing attribute forces the fallback for the whole charge). =1 ONLY when EVERY line
                -- has the attribute. MIN(0/1) over the lines = "all present".
                VolumeComplete = MIN(CASE WHEN l.ItemVolumeRaw    > 0 THEN 1 ELSE 0 END),
                DutyComplete   = MIN(CASE WHEN l.DutyRateCombined > 0 THEN 1 ELSE 0 END),
                WeightComplete = MIN(CASE WHEN l.CaseWeightRaw    > 0 THEN 1 ELSE 0 END)
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
                        -- 2026-06-29: guard changed from "ISNULL(st.TotalXxx,0) > 0" (ANY line has the
                        -- basis) to "st.XxxComplete = 1" (EVERY line has it). If any line is missing the
                        -- attribute these dimensional WHENs all fail and it falls through to BY_VALUE.
                        -- WHEN c.AllocationMethod IN ('BY_DUTY', 'BY_TARIFF') AND ISNULL(st.TotalDutyWgt, 0) > 0 THEN l.DutyWeight
                        -- WHEN c.AllocationMethod = 'BY_VOLUME'               AND ISNULL(st.TotalVolume, 0)  > 0 THEN l.LineVolume
                        -- WHEN c.AllocationMethod = 'BY_WEIGHT'               AND ISNULL(st.TotalWeight, 0)  > 0 THEN l.LineWeight
                        WHEN c.AllocationMethod IN ('BY_DUTY', 'BY_TARIFF') AND st.DutyComplete   = 1 THEN l.DutyWeight
                        WHEN c.AllocationMethod = 'BY_VOLUME'               AND st.VolumeComplete = 1 THEN l.LineVolume
                        WHEN c.AllocationMethod = 'BY_WEIGHT'               AND st.WeightComplete = 1 THEN l.LineWeight
                        --WHEN c.AllocationMethod = 'BY_PALLET'               AND ISNULL(st.TotalPallet, 0)  > 0 THEN l.LinePallet
                        WHEN c.AllocationMethod = 'BY_QUANTITY'              AND ISNULL(st.TotalQty, 0)    > 0  THEN l.LineQty
                        ELSE l.LineValue
                    END,

                TotalBasis =
                    CASE
                        -- 2026-06-29: same all-or-nothing guard swap (keep LineBasis & TotalBasis in lockstep)
                        -- WHEN c.AllocationMethod IN ('BY_DUTY', 'BY_TARIFF') AND ISNULL(st.TotalDutyWgt, 0) > 0 THEN st.TotalDutyWgt
                        -- WHEN c.AllocationMethod = 'BY_VOLUME'               AND ISNULL(st.TotalVolume, 0)  > 0 THEN st.TotalVolume
                        -- WHEN c.AllocationMethod = 'BY_WEIGHT'               AND ISNULL(st.TotalWeight, 0)  > 0 THEN st.TotalWeight
                        WHEN c.AllocationMethod IN ('BY_DUTY', 'BY_TARIFF') AND st.DutyComplete   = 1 THEN st.TotalDutyWgt
                        WHEN c.AllocationMethod = 'BY_VOLUME'               AND st.VolumeComplete = 1 THEN st.TotalVolume
                        WHEN c.AllocationMethod = 'BY_WEIGHT'               AND st.WeightComplete = 1 THEN st.TotalWeight
                        --WHEN c.AllocationMethod = 'BY_PALLET'               AND ISNULL(st.TotalPallet, 0)  > 0 THEN st.TotalPallet
                        WHEN c.AllocationMethod = 'BY_QUANTITY'              AND ISNULL(st.TotalQty, 0)    > 0  THEN st.TotalQty
                        ELSE st.TotalValue
                    END,

                UsedMethod =
                    CASE
                        -- 2026-06-29: same all-or-nothing guard swap. When a dimensional method can't be
                        -- honored (>=1 line missing data) it is stamped 'BY_VALUE_FALLBACK' so the
                        -- fallback is auditable in ShipmentAllocation.AllocationMethod.
                        -- WHEN c.AllocationMethod = 'BY_DUTY'    AND ISNULL(st.TotalDutyWgt, 0) > 0 THEN 'BY_DUTY'
                        -- WHEN c.AllocationMethod = 'BY_TARIFF'  AND ISNULL(st.TotalDutyWgt, 0) > 0 THEN 'BY_TARIFF'
                        -- WHEN c.AllocationMethod = 'BY_VOLUME'  AND ISNULL(st.TotalVolume, 0)  > 0 THEN 'BY_VOLUME'
                        -- WHEN c.AllocationMethod = 'BY_WEIGHT'  AND ISNULL(st.TotalWeight, 0)  > 0 THEN 'BY_WEIGHT'
                        WHEN c.AllocationMethod = 'BY_DUTY'    AND st.DutyComplete   = 1 THEN 'BY_DUTY'
                        WHEN c.AllocationMethod = 'BY_TARIFF'  AND st.DutyComplete   = 1 THEN 'BY_TARIFF'
                        WHEN c.AllocationMethod = 'BY_VOLUME'  AND st.VolumeComplete = 1 THEN 'BY_VOLUME'
                        WHEN c.AllocationMethod = 'BY_WEIGHT'  AND st.WeightComplete = 1 THEN 'BY_WEIGHT'
                        --WHEN c.AllocationMethod = 'BY_PALLET'  AND ISNULL(st.TotalPallet, 0)  > 0 THEN 'BY_PALLET'
                        WHEN c.AllocationMethod = 'BY_QUANTITY' AND ISNULL(st.TotalQty, 0)    > 0  THEN 'BY_QUANTITY'
                        WHEN c.AllocationMethod IN ('BY_DUTY', 'BY_TARIFF', 'BY_VOLUME', 'BY_WEIGHT', 'BY_PALLET', 'BY_QUANTITY')
                            THEN 'BY_VALUE_FALLBACK'
                        ELSE 'BY_VALUE'
                    END,

                rn = ROW_NUMBER() OVER (
                    PARTITION BY c.ChargeId
                    ORDER BY
                        CASE
                            -- 2026-06-29: same all-or-nothing guard swap (order rows by the basis actually used)
                            -- WHEN c.AllocationMethod IN ('BY_DUTY', 'BY_TARIFF') AND ISNULL(st.TotalDutyWgt, 0) > 0 THEN l.DutyWeight
                            -- WHEN c.AllocationMethod = 'BY_VOLUME'               AND ISNULL(st.TotalVolume, 0)  > 0 THEN l.LineVolume
                            -- WHEN c.AllocationMethod = 'BY_WEIGHT'               AND ISNULL(st.TotalWeight, 0)  > 0 THEN l.LineWeight
                            WHEN c.AllocationMethod IN ('BY_DUTY', 'BY_TARIFF') AND st.DutyComplete   = 1 THEN l.DutyWeight
                            WHEN c.AllocationMethod = 'BY_VOLUME'               AND st.VolumeComplete = 1 THEN l.LineVolume
                            WHEN c.AllocationMethod = 'BY_WEIGHT'               AND st.WeightComplete = 1 THEN l.LineWeight
                            --WHEN c.AllocationMethod = 'BY_PALLET'               AND ISNULL(st.TotalPallet, 0)  > 0 THEN l.LinePallet
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
               --OR  ISNULL(st.TotalPallet, 0)  > 0
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
