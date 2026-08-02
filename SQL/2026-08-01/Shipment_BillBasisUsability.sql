SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =====================================================================
-- Shipment_BillBasisUsability   -- EXEC dbo.Shipment_BillBasisUsability @ShipmentId=31
-- Marker: SCR_C_BILLBASISUSABILITY_20260710
-- READ-ONLY. One row per assigned bill (ShipmentPurchase) of the shipment, with per-bill
-- basis usability flags + totals, so the split helper (Phase C) can resolve freight LineBasis
-- and derive duty amounts in the service layer WITHOUT duplicating landed-cost math.
--   SQL owns line eligibility + weight expressions (identical to Shipment_Allocation / Phase B).
--   Flags mirror the allocator's fail-fast rules:
--     VolumeOk/WeightOk = every eligible inventory line has the raw attribute AND the bill total > 0
--                         (all-or-nothing, like Shipment_AllocateWithinBill's BY_VOLUME/BY_WEIGHT).
--     ValueOk/QuantityOk = bill total > 0.
--     DutyTariffOk = bill total duty/tariff weight > 0 (non-dutiable lines contribute 0 naturally).
--   DutyTariffAmount = the per-bill duty charge amount (= SUM(LineValue x (CustomDutyRate+TariffPercent))).
-- Bills with no eligible inventory lines still return a row (all flags 0, totals 0).
-- =====================================================================
CREATE OR ALTER PROCEDURE [dbo].[Shipment_BillBasisUsability]
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH L AS (
        -- eligible inventory lines per bill, with each basis weight (live Shipment_Allocation expressions)
        SELECT
            sp.ShipmentPurchaseId,
            sp.PurchaseId,
            LineValue  = ISNULL(pd.FinalQty,0)     * ISNULL(pd.FinalPrice,0),
            LineVol    = ISNULL(pd.BaseFinalQty,0) * ISNULL(pd.ItemVolume,0),
            LineWgt    = ISNULL(pd.BaseFinalQty,0) * ISNULL(i.CaseWeight,0),
            LineQty    = ISNULL(pd.BaseFinalQty,0),
            DutyWeight = (ISNULL(pd.FinalQty,0)*ISNULL(pd.FinalPrice,0)) * (ISNULL(pd.CustomDutyRate,0)+ISNULL(pd.TariffPercent,0)),
            VolRaw     = ISNULL(pd.ItemVolume,0),
            WgtRaw     = ISNULL(i.CaseWeight,0)
        FROM   dbo.ShipmentPurchase sp
        JOIN   dbo.PurchaseDetail pd ON pd.PurchaseId = sp.PurchaseId AND pd.ItemId IS NOT NULL
        JOIN   dbo.Item i ON i.ItemId = pd.ItemId AND i.ItemType = 'Inventory'
        WHERE  sp.ShipmentId = @ShipmentId
    ),
    E AS (
        -- drop lines that can't be allocated in ANY basis (matches Shipment_AllocateWithinBill's #Lines cleanup)
        SELECT * FROM L
        WHERE NOT (ISNULL(LineValue,0) <= 0 AND ISNULL(LineVol,0) <= 0 AND ISNULL(DutyWeight,0) <= 0
                   AND ISNULL(LineWgt,0) <= 0 AND ISNULL(LineQty,0) <= 0)
    ),
    A AS (
        SELECT
            ShipmentPurchaseId, PurchaseId,
            LineCount   = COUNT(*),
            TotalValue  = SUM(LineValue),
            TotalVol    = SUM(LineVol),
            TotalWgt    = SUM(LineWgt),
            TotalQty    = SUM(LineQty),
            TotalDuty   = SUM(DutyWeight),
            VolComplete = MIN(CASE WHEN VolRaw > 0 THEN 1 ELSE 0 END),
            WgtComplete = MIN(CASE WHEN WgtRaw > 0 THEN 1 ELSE 0 END)
        FROM   E
        GROUP BY ShipmentPurchaseId, PurchaseId
    )
    SELECT
        sp.ShipmentPurchaseId,
        sp.PurchaseId,
        VolumeOk              = CASE WHEN ISNULL(a.VolComplete,0)=1 AND ISNULL(a.TotalVol,0) > 0 THEN 1 ELSE 0 END,
        WeightOk              = CASE WHEN ISNULL(a.WgtComplete,0)=1 AND ISNULL(a.TotalWgt,0) > 0 THEN 1 ELSE 0 END,
        ValueOk               = CASE WHEN ISNULL(a.TotalValue,0) > 0 THEN 1 ELSE 0 END,
        QuantityOk            = CASE WHEN ISNULL(a.TotalQty,0)   > 0 THEN 1 ELSE 0 END,
        DutyTariffOk          = CASE WHEN ISNULL(a.TotalDuty,0)  > 0 THEN 1 ELSE 0 END,
        DutyTariffAmount      = CAST(ROUND(ISNULL(a.TotalDuty,0), 2) AS DECIMAL(18,2)),
        LineCount             = ISNULL(a.LineCount, 0),
        TotalValue            = CAST(ISNULL(a.TotalValue,0) AS DECIMAL(18,2)),
        TotalQty              = CAST(ISNULL(a.TotalQty,0)   AS DECIMAL(18,4)),
        TotalDutyTariffWeight = CAST(ISNULL(a.TotalDuty,0)  AS DECIMAL(18,4)),
        IsDropShip            = pr2.IsDropShip
    FROM   dbo.ShipmentPurchase sp
    LEFT JOIN A a ON a.ShipmentPurchaseId = sp.ShipmentPurchaseId
    JOIN   dbo.Purchase pr2 ON pr2.PurchaseId = sp.PurchaseId
    WHERE  sp.ShipmentId = @ShipmentId
    ORDER BY sp.ShipmentPurchaseId;
END
