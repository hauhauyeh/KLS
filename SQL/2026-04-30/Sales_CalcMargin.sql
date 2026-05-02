/*
    Purpose:
      Calculates and updates SalesMarginPercent and SalesMarginOrderPercent
      for a given SalesId.

    Margin formulas:
      SalesMarginPercent      = (SubTotal - CostInvoiceStage) / SubTotal
      SalesMarginOrderPercent = (SubTotal - CostOrderStage)   / SubTotal

    Cost rules:
      - Invoice stage:
            FIFOCost if present,
            otherwise ItemUnit.RecentCost
      - Order stage:
            FIFOCostOrder if present,
            otherwise ItemUnit.RecentCost

      - ItemUnit cost is taken from the ACTIVE BASE UNIT (IsBaseUnit = 1)
      - BaseShipQty is already in base units
      - RecentCost already includes current landed/import allocation logic,
        so FreightCost is not added separately
*/
CREATE OR ALTER PROCEDURE [dbo].[Sales_CalcMargin]
    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Costs AS
    (
        SELECT
            sd.SalesId,

            -- Invoice-stage cost
            SUM(
                COALESCE(
                    sd.FIFOCost,
                    iu.RecentCost
                ) * sd.BaseShipQty
            ) AS CostInvoiceStage,

            -- Order-stage cost
            SUM(
                COALESCE(
                    sd.FIFOCostOrder,
                    iu.RecentCost
                ) * sd.BaseShipQty
            ) AS CostOrderStage

        FROM dbo.SalesDetail sd
        INNER JOIN dbo.ItemUnit iu ON iu.ItemId = sd.ItemId
        AND iu.IsBaseUnit = 1
        AND iu.Inactive = 0
        WHERE sd.SalesId = @SalesId
        GROUP BY sd.SalesId
    )
    UPDATE s
        SET
            s.SalesMarginPercent      = (s.SubTotal - c.CostInvoiceStage) / NULLIF(s.SubTotal, 0),
            s.SalesMarginOrderPercent = (s.SubTotal - c.CostOrderStage)   / NULLIF(s.SubTotal, 0)
    FROM dbo.Sales s
    INNER JOIN Costs c ON c.SalesId = s.SalesId
    WHERE s.SalesId = @SalesId;
END;
