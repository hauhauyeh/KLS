SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
    Purpose:
      Calculates and updates SalesMarginPercent and SalesMarginOrderPercent
      for a given SalesId.
    Margin formulas:
      SalesMarginPercent      = (SubTotal - CostInvoiceStage) / SubTotal
      SalesMarginOrderPercent = (SubTotal - CostOrderStage)   / SubTotal
    Cost rules:
      - 2026-06-27: switched to RecentCost ONLY for BOTH stages (was: FIFOCost /
        FIFOCostOrder with a RecentCost fallback). Rationale: the stored Sales
        margin is a rough/operational figure; FIFOCost/FIFOCostOrder are NULL/0
        across KLS_2026 (weighted-avg DB, FIFO gated off by ITEM_USE_EXPIRYDATE),
        so the old COALESCE already fell back to RecentCost in practice. The
        accurate reports (Sales By Invoice, Sales Commission 3) now read the real
        @COGS journal directly and no longer depend on this stored margin. Using
        RecentCost only makes the figure consistently populated and frees the
        FIFOCost / FIFOCostOrder columns for other use (e.g. allocation status).
        NOTE: with both stages on RecentCost, CostInvoiceStage = CostOrderStage,
        so SalesMarginPercent == SalesMarginOrderPercent. Both are still written
        for column/consumer compatibility (e.g. Report_SalesDaily2).
      - ItemUnit cost is taken from the ACTIVE BASE UNIT (IsBaseUnit = 1)
      - BaseShipQty is already in base units
      - RecentCost already includes current landed/import allocation logic,
        so FreightCost is not added separately
*/
DROP PROCEDURE IF EXISTS [dbo].[Sales_CalcMargin]
GO
CREATE PROCEDURE [dbo].[Sales_CalcMargin] -- EXEC Sales_CalcMargin @SalesId=72672
    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON;
    ;WITH Costs AS
    (
        SELECT
            sd.SalesId,
            -- 2026-06-27: both stages now use RecentCost only. Old FIFO-coalesce kept below.
            -- Invoice-stage cost
            -- SUM(COALESCE(sd.FIFOCost,      iu.RecentCost) * sd.BaseShipQty) AS CostInvoiceStage,
            SUM(iu.RecentCost * sd.BaseShipQty) AS CostInvoiceStage,
            -- Order-stage cost
            -- SUM(COALESCE(sd.FIFOCostOrder, iu.RecentCost) * sd.BaseShipQty) AS CostOrderStage
            SUM(iu.RecentCost * sd.BaseShipQty) AS CostOrderStage
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
END
GO
