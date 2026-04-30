
CREATE VIEW [dbo].[View_PurchaseHistory] AS
WITH RankedCosts AS (
    SELECT
        i.ItemId,
        i.ItemCode,
        i.ItemName,
        p.PayeeId,
        p.PurchaseId,
        p.PurchaseNumber,
        p.VendorDocNumber,
        p.ArrivalDate,
        p.FreightTotal,
        pd.PurchaseDetailId,
        pd.Unit,
        pd.ShipQty,
        pd.BillQty,
        pd.ReceiveQty,
        pd.FinalQty,
        pd.FinalPrice,
        pd.BaseReceiveQty,
        pd.BaseFinalQty,
        pd.ExpiryDate,

        -- Base cost
        ROUND(
            CASE
                WHEN pd.FactorToBase = 1 THEN pd.FinalPrice
                WHEN pd.FactorToBase <> 1 THEN pd.FinalPrice * ISNULL(NULLIF(pd.FactorToBase, 0), 1)
                ELSE pd.FinalPrice
            END,
        2) AS BaseCost,

        ISNULL(LandedCost,0) AS LandedCost,
        ROUND(
        CASE
            WHEN BaseFinalQty = 0 THEN 0
            ELSE (ISNULL(LandedCost,0) + ISNULL(pd.ImportCommission,0)) / BaseFinalQty
        END
        , 2) AS LandedCostPerCase,

        -- Freight per case
        --ROUND(
        --    CASE
        --        WHEN p.FreightTotal != 0 AND pd.BaseFinalQty != 0 THEN
        --            (p.FreightTotal * ISNULL(pd.VolumeSharePercent, 0)) / pd.BaseFinalQty
        --        ELSE
        --            (SELECT ISNULL(v.FreightRate,0) FROM Vendor AS v WHERE v.PayeeId = p.PayeeId) /
        --            (CASE WHEN i.PaletteFactor > 0 THEN i.PaletteFactor ELSE 50 END)
        --    END,
        --2) AS FreightPerCase,

        ---- Duty per case
        --ROUND(
        --    CASE
        --        WHEN pd.BaseFinalQty != 0 THEN
        --            (ISNULL(p.CustomDutyTotal, 0) * ISNULL(pd.DutySharePercent, 0)) / pd.BaseFinalQty
        --        ELSE 0
        --    END,
        --2) AS DutyPerCase,

        -- Deprecated: old PaletteFactor-based freight estimate retained only as commented reference.
        --ROUND(
        --    CASE
        --        WHEN ISNULL(p.PalletCount, 0) * ISNULL(i.PaletteFactor, 0) > 0 THEN
        --            p.FreightTotal / (p.PalletCount * i.PaletteFactor)
        --        ELSE 0
        --    END,
        --2) AS PaletteFreight,
        CAST(0 AS DECIMAL(18,2)) AS PaletteFreight,

        ROW_NUMBER() OVER (
            PARTITION BY pd.ItemId
            ORDER BY p.ArrivalDate DESC,p.PurchaseId DESC
        ) AS RN

    FROM Purchase AS p
    INNER JOIN PurchaseDetail AS pd ON p.PurchaseId = pd.PurchaseId
    INNER JOIN Item AS i ON i.ItemId = pd.ItemId
    WHERE
        pd.ReceiveQty > 0
        AND pd.FinalPrice > 0
)

SELECT *,
-- 2026-04-20: keep purchase history cost NULL-safe so a missed landed-cost
-- write cannot null out downstream RecentCost calculations.
BaseCost + ISNULL(LandedCostPerCase, 0) AS TotalCost
--BaseCost + FreightPerCase + DutyPerCase AS TotalCost
FROM RankedCosts

