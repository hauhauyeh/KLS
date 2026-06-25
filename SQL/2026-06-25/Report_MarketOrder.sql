SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Report_MarketOrder]
    @StartDate DATE,
    @EndDate DATE,
    @AccountId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        moi.MarketOrderItemId,
        mo.MarketOrderId,
        mo.ExternalOrderNo,
        mo.SalesChannel,
        CAST(mo.OrderDate AS DATE) AS OrderDate,
        mo.CustomerName,
        mo.ShipToCity,
        mo.ShipToState,
        mo.OrderStatus,
        mo.OrderTotal,
        mo.TaxAmount,
        mo.CurrencyCode,
        cnt.TotalItems,
        cnt.MatchedItems,
        mo.ImportedToErp,
        mo.ErpSalesId,
        moi.ExternalSku,
        moi.ExternalItemName,
        moi.Qty,
        moi.UnitPrice,
        moi.LineTotal,
        moi.MatchStatus,
        i.ItemName
    FROM MarketOrder mo
    INNER JOIN MarketOrderItem moi ON moi.MarketOrderId = mo.MarketOrderId
    LEFT JOIN Item i ON i.ItemId = moi.ItemId
    CROSS APPLY (
        SELECT
            COUNT(*) AS TotalItems,
            SUM(CASE WHEN mi.MatchStatus <> 'unmatched' THEN 1 ELSE 0 END) AS MatchedItems
        FROM MarketOrderItem mi
        WHERE mi.MarketOrderId = mo.MarketOrderId
    ) cnt
    WHERE mo.ImportedToErp = 0
      AND CAST(mo.OrderDate AS DATE) >= @StartDate
      AND CAST(mo.OrderDate AS DATE) <= @EndDate
      AND (@AccountId IS NULL OR mo.MarketAccountId = @AccountId)
    ORDER BY mo.OrderDate, mo.ExternalOrderNo, moi.MarketOrderItemId
END
GO
