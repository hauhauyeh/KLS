SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[VendorPurchaseHistory_GetPanel];
GO

CREATE PROCEDURE [dbo].[VendorPurchaseHistory_GetPanel] -- EXEC VendorPurchaseHistory_GetPanel @PayeeId=200166
    @PayeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CutoffDate DATE = DATEADD(YEAR, -1, GETDATE());
    DECLARE @RecentDate DATE = DATEADD(MONTH, -3, GETDATE());

    /*
        Vendor Purchase History panel data for the side drawer in
        po-add-edit / purchase-add-edit (Bill).

        Mirror of CustBoughtItems_GetPanel adapted for the vendor side.
        One load, three tabs derived client-side: Top 20 (by TotalQty1Y),
        Recent (3M, sorted by LastPurchaseDate), All (by category).

        Scope (decision #3 in vendor-purchase-history-panel-plan.md):
        include ALL stages — open POs, shipped, partially received,
        received, billed. Hiding open/in-transit rows would weaken the
        feature; the user is recalling the vendor-item relationship.
        LastPurchaseStage chip carries the status nuance.

        Date anchor: COALESCE(InvoiceDate, ArrivalDate, PurchaseDate,
        EnterDate).
          - Billed rows  → InvoiceDate (vendor's invoice date)
          - Received-only → ArrivalDate (when goods landed)
          - Open/Shipped → PurchaseDate (PO date) or EnterDate as
                           ultimate fallback

        Qty rollup: COALESCE(pd.BaseFinalQty, pd.BaseReceiveQty, 0).
        Open POs with nothing received yet contribute 0 to the qty
        totals but still produce a row (the vendor-item link still
        matters even if no goods arrived). 1Y/3M aggregates only
        count actual received/billed qty.

        PayeeType / DocType filter intentionally omitted: Purchase
        rows always represent inbound inventory from a vendor; there
        is no SO-style document discriminator on Purchase that needs
        to be excluded here.
    */

    ;WITH EligiblePurchases AS (
        SELECT
            p.PurchaseId,
            p.StageId,
            COALESCE(p.InvoiceDate, p.ArrivalDate, p.PurchaseDate, p.EnterDate) AS AnchorDate
        FROM dbo.Purchase p
        WHERE p.PayeeId = @PayeeId
          AND COALESCE(p.InvoiceDate, p.ArrivalDate, p.PurchaseDate, p.EnterDate) >= @CutoffDate
    ),
    LatestItemPurchase AS (
        -- For each item, pick the most recent purchase that included it.
        -- LastPurchaseQty comes from THAT one purchase (sum of detail rows
        -- for the same item within it); LastStageId tells the UI whether
        -- that most recent row is still in flight.
        SELECT
            pd.ItemId,
            ep.AnchorDate                                                       AS LastPurchaseDate,
            ep.StageId                                                          AS LastStageId,
            ISNULL(SUM(COALESCE(pd.BaseFinalQty, pd.BaseReceiveQty, 0)), 0)     AS LastPurchaseQty,
            ROW_NUMBER() OVER (
                PARTITION BY pd.ItemId
                ORDER BY ep.AnchorDate DESC, ep.PurchaseId DESC
            ) AS rn
        FROM EligiblePurchases ep
        INNER JOIN dbo.PurchaseDetail pd ON pd.PurchaseId = ep.PurchaseId
        GROUP BY pd.ItemId, ep.PurchaseId, ep.AnchorDate, ep.StageId
    ),
    ItemAgg AS (
        SELECT
            pd.ItemId,
            MAX(ep.AnchorDate)                                                  AS LastPurchaseDate,
            ISNULL(SUM(COALESCE(pd.BaseFinalQty, pd.BaseReceiveQty, 0)), 0)     AS TotalQty1Y,
            ISNULL(SUM(CASE WHEN ep.AnchorDate >= @RecentDate
                            THEN COALESCE(pd.BaseFinalQty, pd.BaseReceiveQty, 0)
                            ELSE 0 END), 0)                                     AS TotalQty3M,
            COUNT(DISTINCT ep.PurchaseId)                                       AS PurchaseCount1Y
        FROM EligiblePurchases ep
        INNER JOIN dbo.PurchaseDetail pd ON pd.PurchaseId = ep.PurchaseId
        GROUP BY pd.ItemId
    )
    SELECT
        i.ItemId,
        i.ItemCode,
        i.ItemName,
        i.SetPacking,
        vc.Cat0                AS CategoryName,
        vc.Sort0               AS CategorySort,
        agg.LastPurchaseDate,
        latest.LastPurchaseQty,
        ps.StageName           AS LastPurchaseStage,
        agg.TotalQty1Y,
        agg.TotalQty3M,
        agg.PurchaseCount1Y
    FROM ItemAgg agg
    INNER JOIN LatestItemPurchase latest
        ON latest.ItemId = agg.ItemId
       AND latest.rn    = 1
    INNER JOIN dbo.Item i           ON i.ItemId       = agg.ItemId
    LEFT JOIN  dbo.View_Category vc ON vc.CategoryId  = i.CategoryId
    LEFT JOIN  dbo.PurchaseStage ps ON ps.StageId     = latest.LastStageId
    WHERE i.Inactive = 0
    ORDER BY vc.Sort0, i.ItemName;
END
GO
