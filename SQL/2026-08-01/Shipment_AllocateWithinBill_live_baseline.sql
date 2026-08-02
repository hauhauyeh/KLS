
-- =====================================================================
-- Shipment_AllocateWithinBill   -- EXEC dbo.Shipment_AllocateWithinBill @PurchaseId=12164,@RefreshVolume=1
-- Marker: SCR_B_WITHIN_BILL_20260710
-- Phase B: allocate NEW per-bill charges (ShipmentCharge.ShipmentPurchaseId IS NOT NULL)
-- down to their own bill's inventory lines, per ShipmentCharge.LineBasis.
--   - Legacy (ShipmentPurchaseId NULL) charges are NOT processed here (owned by Shipment_Allocation).
--   - Billed-stage gate (Purchase.StageId = 6) mirrors Shipment_Allocation.
--   - @RefreshVolume mirrors Shipment_Allocation: refresh PurchaseDetail.ItemVolume before allocation.
--   - Writes ShipmentAllocation (grain ChargeId x PurchaseDetailId), then recomputes
--     PurchaseDetail.LandedCost = SUM(ShipmentAllocation.AllocatedAmount) per affected line.
--   - Freight LineBasis is the RESOLVED value the helper stored; treated as authoritative -> FAIL FAST
--     if no longer usable (does NOT re-cascade). Manual/other (LineBasis NULL) is OUT OF SCOPE -> fail.
-- =====================================================================
CREATE   PROCEDURE [dbo].[Shipment_AllocateWithinBill]
    @PurchaseId    INT,
    @RefreshVolume BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Billed-stage gate (mirrors Shipment_Allocation: only allocate for Billed purchases).
    DECLARE @StageId INT;
    DECLARE @IsDropShip BIT = 0;   -- 2026-07-17 NO_LANDED_COST: drop-ship bills never receive landed cost.

    SELECT @StageId = StageId,
           @IsDropShip = ISNULL(IsDropShip, 0)
    FROM dbo.Purchase
    WHERE PurchaseId = @PurchaseId;

    IF @StageId <> 6
        RETURN;

    -- 2026-07-17 NO_LANDED_COST: a drop-ship bill can carry freight split/audit rows, but those
    -- rows must never create landed cost. Clear any stale landed cost on its own lines and return
    -- before guard/charge processing so sibling split rows do not raise false allocation errors.
    IF @IsDropShip = 1
    BEGIN
        UPDATE dbo.PurchaseDetail
        SET    LandedCost = 0
        WHERE  PurchaseId = @PurchaseId
          AND  ISNULL(LandedCost, 0) <> 0;

        RETURN;
    END

    -- Mixed-scope guard (strict): fail if a shipment carrying this purchase has BOTH
    -- a legacy shipment-wide charge and a per-bill charge.
    IF EXISTS (
        SELECT 1
        FROM   dbo.ShipmentPurchase sp
        WHERE  sp.PurchaseId = @PurchaseId
          AND  EXISTS (SELECT 1 FROM dbo.ShipmentCharge lc
                       WHERE lc.ShipmentId = sp.ShipmentId
                         AND lc.ShipmentPurchaseId IS NULL
                         AND ISNULL(lc.ChargeAmount,0) <> 0)
          AND  EXISTS (SELECT 1 FROM dbo.ShipmentCharge nc
                       JOIN dbo.ShipmentPurchase sp2 ON sp2.ShipmentPurchaseId = nc.ShipmentPurchaseId
                       JOIN dbo.Purchase p2 ON p2.PurchaseId = sp2.PurchaseId
                       WHERE sp2.ShipmentId = sp.ShipmentId
                         AND nc.ShipmentPurchaseId IS NOT NULL
                         AND ISNULL(p2.IsDropShip, 0) = 0
                         AND ISNULL(nc.LineBasis, '') <> 'NO_LANDED_COST'
                         AND ISNULL(nc.ChargeAmount,0) <> 0)
    )
    BEGIN
        RAISERROR('Shipment_AllocateWithinBill: mixed scope - a shipment has both legacy shipment-wide and per-bill charges. Reverse the legacy charge first.', 16, 1);
        RETURN;
    END

    -- Manual/other per-bill charges (LineBasis NULL) are out of scope for Phase B.
    IF EXISTS (
        SELECT 1
        FROM   dbo.ShipmentCharge sc
        JOIN   dbo.ShipmentPurchase sp ON sp.ShipmentPurchaseId = sc.ShipmentPurchaseId
        WHERE  sp.PurchaseId = @PurchaseId
          AND  sc.ShipmentPurchaseId IS NOT NULL
          AND  sc.LineBasis IS NULL
          AND  ISNULL(sc.ChargeAmount,0) <> 0
    )
    BEGIN
        RAISERROR('Shipment_AllocateWithinBill: manual/other per-bill charge (LineBasis NULL) is not supported in Phase B.', 16, 1);
        RETURN;
    END

    -- Optional volume refresh before allocation (mirrors Shipment_Allocation @RefreshVolume).
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

    -- Eligible inventory lines for this bill, with every basis weight (live Shipment_Allocation expressions).
    IF OBJECT_ID('tempdb..#Lines') IS NOT NULL DROP TABLE #Lines;
    SELECT
        pd.PurchaseDetailId,
        LineValue  = ISNULL(pd.FinalQty,0)     * ISNULL(pd.FinalPrice,0),
        LineVolume = ISNULL(pd.BaseFinalQty,0) * ISNULL(pd.ItemVolume,0),
        LineWeight = ISNULL(pd.BaseFinalQty,0) * ISNULL(i.CaseWeight,0),
        LineQty    = ISNULL(pd.BaseFinalQty,0),
        DutyWeight = (ISNULL(pd.FinalQty,0)*ISNULL(pd.FinalPrice,0)) * (ISNULL(pd.CustomDutyRate,0)+ISNULL(pd.TariffPercent,0)),
        VolRaw     = ISNULL(pd.ItemVolume,0),
        WgtRaw     = ISNULL(i.CaseWeight,0)
    INTO   #Lines
    FROM   dbo.PurchaseDetail pd
    JOIN   dbo.Item i ON pd.ItemId = i.ItemId
    WHERE  pd.PurchaseId = @PurchaseId
      AND  i.ItemType = 'Inventory'
      AND  pd.ItemId IS NOT NULL;

    DELETE FROM #Lines
    WHERE ISNULL(LineValue,0)  <= 0
      AND ISNULL(LineVolume,0) <= 0
      AND ISNULL(DutyWeight,0) <= 0
      AND ISNULL(LineWeight,0) <= 0
      AND ISNULL(LineQty,0)    <= 0;

    -- Per-bill charges to allocate (freight + duty; LineBasis NOT NULL).
    -- 2026-07-17 NO_LANDED_COST: no-landed-cost/drop-ship rows are part of charge split
    -- reconciliation only. They are intentionally excluded from ShipmentAllocation writes.
    IF OBJECT_ID('tempdb..#Charges') IS NOT NULL DROP TABLE #Charges;
    SELECT sc.ChargeId, sc.LineBasis, ChargeAmount = CAST(ISNULL(sc.ChargeAmount,0) AS DECIMAL(18,2))
    INTO   #Charges
    FROM   dbo.ShipmentCharge sc
    JOIN   dbo.ShipmentPurchase sp ON sp.ShipmentPurchaseId = sc.ShipmentPurchaseId
    JOIN   dbo.Purchase p ON p.PurchaseId = sp.PurchaseId
    WHERE  sp.PurchaseId = @PurchaseId
      AND  sc.ShipmentPurchaseId IS NOT NULL
      AND  sc.LineBasis IS NOT NULL
      AND  sc.LineBasis <> 'NO_LANDED_COST'
      AND  ISNULL(p.IsDropShip, 0) = 0
      AND  ISNULL(sc.ChargeAmount,0) <> 0;

    DECLARE @ChargeId INT, @LineBasis VARCHAR(20), @Amt DECIMAL(18,2), @Total DECIMAL(38,10), @Residual DECIMAL(18,2);

    BEGIN TRY
        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT ChargeId, LineBasis, ChargeAmount FROM #Charges;
        OPEN cur;
        FETCH NEXT FROM cur INTO @ChargeId, @LineBasis, @Amt;

        BEGIN TRAN;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- per-line weight for this charge's basis
            IF OBJECT_ID('tempdb..#W') IS NOT NULL DROP TABLE #W;
            SELECT PurchaseDetailId, VolRaw, WgtRaw,
                   W = CASE @LineBasis
                           WHEN 'BY_VALUE'       THEN LineValue
                           WHEN 'BY_VOLUME'      THEN LineVolume
                           WHEN 'BY_WEIGHT'      THEN LineWeight
                           WHEN 'BY_QUANTITY'    THEN LineQty
                           WHEN 'BY_DUTY_TARIFF' THEN DutyWeight
                       END
            INTO   #W
            FROM   #Lines;

            SET @Total = (SELECT SUM(W) FROM #W);

            -- fail-fast usability (caught by CATCH -> full rollback)
            IF @LineBasis = 'BY_VOLUME' AND EXISTS (SELECT 1 FROM #W WHERE VolRaw <= 0)
                RAISERROR('Charge %d: stored BY_VOLUME no longer usable (a line has no volume).',16,1,@ChargeId);
            IF @LineBasis = 'BY_WEIGHT' AND EXISTS (SELECT 1 FROM #W WHERE WgtRaw <= 0)
                RAISERROR('Charge %d: stored BY_WEIGHT no longer usable (a line has no weight).',16,1,@ChargeId);
            IF ISNULL(@Total,0) <= 0
                RAISERROR('Charge %d: total basis weight is zero for %s.',16,1,@ChargeId,@LineBasis);

            -- clear this charge's prior audit rows
            DELETE FROM dbo.ShipmentAllocation WHERE ChargeId = @ChargeId;

            -- rounded allocation; residual (to the cent) to the largest-weight line, tiebreak PurchaseDetailId ASC
            IF OBJECT_ID('tempdb..#A') IS NOT NULL DROP TABLE #A;
            SELECT PurchaseDetailId,
                   Amt = CAST(ROUND(@Amt * W / @Total, 2) AS DECIMAL(18,2)),
                   rn  = ROW_NUMBER() OVER (ORDER BY W DESC, PurchaseDetailId ASC)
            INTO   #A
            FROM   #W
            WHERE  W > 0;

            SET @Residual = @Amt - (SELECT SUM(Amt) FROM #A);

            INSERT INTO dbo.ShipmentAllocation (ChargeId, PurchaseDetailId, AllocatedAmount, AllocationMethod, CreatedAt)
            SELECT @ChargeId, a.PurchaseDetailId,
                   a.Amt + CASE WHEN a.rn = 1 THEN @Residual ELSE 0 END,
                   @LineBasis, GETUTCDATE()
            FROM   #A a;

            FETCH NEXT FROM cur INTO @ChargeId, @LineBasis, @Amt;
        END

        -- recompute LandedCost from the FINAL ledger for this bill's lines (includes sibling charges)
        UPDATE pd
        SET    pd.LandedCost = ISNULL(x.S, 0.00)
        FROM   dbo.PurchaseDetail pd
        OUTER APPLY (SELECT S = SUM(sa.AllocatedAmount)
                     FROM   dbo.ShipmentAllocation sa
                     WHERE  sa.PurchaseDetailId = pd.PurchaseDetailId) x
        WHERE  pd.PurchaseId = @PurchaseId;

        COMMIT TRAN;
        IF CURSOR_STATUS('local','cur') >= 0  CLOSE cur;
        IF CURSOR_STATUS('local','cur') >= -1 DEALLOCATE cur;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        IF CURSOR_STATUS('local','cur') >= 0  CLOSE cur;
        IF CURSOR_STATUS('local','cur') >= -1 DEALLOCATE cur;
        ;THROW;
    END CATCH
END
