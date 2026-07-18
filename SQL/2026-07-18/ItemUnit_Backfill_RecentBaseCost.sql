-- =============================================================================
-- ItemUnit_Backfill_RecentBaseCost -- ONE-OFF backfill (run after column add + SP deploy).
-- 2026-07-18 (PO pure-cost default, step 3). Seed RecentBaseCost for all items with
--   purchase history, mirroring ItemUnit_UpdateRecentCost scaling. Items with no
--   history stay NULL -> C# falls back to RecentCost.
-- Plan: plan/po-item-base-cost-default-v2.md
-- =============================================================================
SET QUOTED_IDENTIFIER ON
GO

;WITH LatestCost AS
(
    SELECT ItemId, BaseCost
    FROM dbo.View_PurchaseHistory
    WHERE RN = 1
)
UPDATE iu
SET iu.RecentBaseCost = ROUND(lc.BaseCost * ISNULL(NULLIF(iu.MultipleToBase, 0), 1) / NULLIF(iu.FactorToBase, 0), 2)
FROM dbo.ItemUnit iu
INNER JOIN LatestCost lc ON lc.ItemId = iu.ItemId;
GO

-- Sanity check after run: RecentBaseCost <= RecentCost wherever both set (landed >= pure).
-- SELECT TOP 20 iu.ItemId, iu.Unit, iu.RecentCost, iu.RecentBaseCost
-- FROM dbo.ItemUnit iu WHERE iu.RecentBaseCost > iu.RecentCost;
