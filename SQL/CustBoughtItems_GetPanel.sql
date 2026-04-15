SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Customer Bought Items panel data for sales-add-edit side panel.
-- One load, three tabs derived client-side: Top 20, Recent (3M), All (1Y).

CREATE OR ALTER PROCEDURE [dbo].[CustBoughtItems_GetPanel]
    @PayeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CutoffDate DATE = DATEADD(YEAR, -1, GETDATE());
    DECLARE @RecentDate DATE = DATEADD(MONTH, -3, GETDATE());

    ;WITH EligibleSales AS (
        SELECT
            s.SalesId,
            s.ShipDate
        FROM dbo.Sales s
        WHERE s.ShipId = @PayeeId
          AND s.ShipDate >= @CutoffDate
          AND s.SalesTotal > 0
          AND ISNULL(s.DocType, 'SO') = 'SO'
    ),
    LatestItemOrder AS (
        SELECT
            sd.ItemId,
            es.ShipDate AS LastOrderDate,
            SUM(sd.BaseShipQty) AS LastOrderQty,
            ROW_NUMBER() OVER (
                PARTITION BY sd.ItemId
                ORDER BY es.ShipDate DESC, es.SalesId DESC
            ) AS rn
        FROM EligibleSales es
        INNER JOIN dbo.SalesDetail sd ON sd.SalesId = es.SalesId
        GROUP BY sd.ItemId, es.SalesId, es.ShipDate
    ),
    ItemAgg AS (
        SELECT
            sd.ItemId,
            MAX(es.ShipDate) AS LastOrderDate,
            SUM(sd.BaseShipQty) AS TotalQty1Y,
            SUM(CASE WHEN es.ShipDate >= @RecentDate THEN sd.BaseShipQty ELSE 0 END) AS TotalQty3M,
            COUNT(DISTINCT es.SalesId) AS OrderCount1Y
        FROM EligibleSales es
        INNER JOIN dbo.SalesDetail sd ON sd.SalesId = es.SalesId
        GROUP BY sd.ItemId
    )
    SELECT
        i.ItemId,
        i.ItemCode,
        i.ItemName,
        i.SetPacking,
        vc.Cat0 AS CategoryName,
        vc.Sort0 AS CategorySort,
        agg.LastOrderDate,
        latest.LastOrderQty,
        agg.TotalQty1Y,
        agg.TotalQty3M,
        agg.OrderCount1Y
    FROM ItemAgg agg
    INNER JOIN LatestItemOrder latest
        ON latest.ItemId = agg.ItemId
       AND latest.rn = 1
    INNER JOIN dbo.Item i ON i.ItemId = agg.ItemId
    LEFT JOIN dbo.View_Category vc ON vc.CategoryId = i.CategoryId
    WHERE i.Inactive = 0
    ORDER BY vc.Sort0, i.ItemName;
END
GO
