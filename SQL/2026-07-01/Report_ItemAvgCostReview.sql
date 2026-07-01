SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP PROCEDURE IF EXISTS [dbo].[Report_ItemAvgCostReview]
GO
CREATE PROCEDURE [dbo].[Report_ItemAvgCostReview] -- EXEC Report_ItemAvgCostReview
AS
BEGIN
    SET NOCOUNT ON;

    -- Item AvgCost Review (revaluation triage) — thin data feed.
    -- One row per active (non-deleted) item. This SP does NOT compute the triage
    -- verdict: Cost Delta / % Change / Revalue Impact / Cost Age / Status Tag and
    -- the tolerance thresholds are all derived CLIENT-SIDE so the reviewer can tune
    -- Min Impact / Min % / Max Age / Min Outlier live without a server round-trip.
    --
    -- Columns:
    --   OnHand / CurAvgCost / CurInvValue  = current booked state (Item.LCloseQty / LAvgCost / LInventoryValue)
    --   RecentCost      = most-recent purchase LANDED cost per base unit  (View_PurchaseHistory RN=1, TotalCost = BaseCost + LandedCostPerCase)
    --   RecentBaseCost  = same layer's raw base cost (no freight/duty)     (RN=1, BaseCost)
    --   LastPurchaseDate/ LastVendor = the RN=1 layer's arrival + vendor
    --   RN2Cost         = 2nd most-recent landed cost (RN=2) — feeds the RN1-vs-RN2 believability (OUTLIER_CHECK) check
    --   CategoryId      = returned (not just the label) so the frontend can filter by id
    --   CategoryPath    = '/ancestorId/.../categoryId/' materialized path (recursive CTE below) so the
    --                     frontend can subtree-filter reliably: rows where CategoryPath LIKE '%/<selId>/%'
    --                     are the selected category and all its descendants. ID-based, not label matching.
    --
    -- RN=1 is the newest purchase (View_PurchaseHistory ranks ArrivalDate DESC).
    -- View_PurchaseHistory carries PayeeId only, so Payee is joined for the vendor name.

    -- Materialized ancestor-id path per category (root -> self). Categories are a small tree, so the
    -- recursive walk is cheap. A category's Path contains '/<id>/' for itself and every ancestor, so any
    -- descendant's Path contains the selected id -> that's the subtree test done client-side.
    ;WITH CatPath AS (
        SELECT CategoryId, ParentId,
               CAST('/' + CAST(CategoryId AS VARCHAR(12)) + '/' AS VARCHAR(400)) AS Path
        FROM dbo.ItemCategory WHERE ParentId IS NULL
        UNION ALL
        SELECT c.CategoryId, c.ParentId,
               CAST(cp.Path + CAST(c.CategoryId AS VARCHAR(12)) + '/' AS VARCHAR(400))
        FROM dbo.ItemCategory c
        INNER JOIN CatPath cp ON c.ParentId = cp.CategoryId
    )
    SELECT
        i.ItemId,
        i.ItemCode,
        i.ItemName,
        i.CategoryId,
        vc.DisplayName        AS Category,
        cpath.Path            AS CategoryPath,
        i.LCloseQty           AS OnHand,
        i.LAvgCost            AS CurAvgCost,
        i.LInventoryValue     AS CurInvValue,
        rc1.TotalCost         AS RecentCost,
        rc1.BaseCost          AS RecentBaseCost,
        rc1.ArrivalDate       AS LastPurchaseDate,
        p1.PayeeName          AS LastVendor,
        rc2.TotalCost         AS RN2Cost
    FROM dbo.Item i
    LEFT JOIN dbo.View_Category vc         ON vc.CategoryId = i.CategoryId
    LEFT JOIN CatPath cpath                ON cpath.CategoryId = i.CategoryId
    LEFT JOIN dbo.View_PurchaseHistory rc1 ON rc1.ItemId = i.ItemId AND rc1.RN = 1
    LEFT JOIN dbo.Payee p1                 ON p1.PayeeId = rc1.PayeeId
    LEFT JOIN dbo.View_PurchaseHistory rc2 ON rc2.ItemId = i.ItemId AND rc2.RN = 2
    WHERE i.IsDeleted = 0
    ORDER BY i.ItemCode;
END
GO
