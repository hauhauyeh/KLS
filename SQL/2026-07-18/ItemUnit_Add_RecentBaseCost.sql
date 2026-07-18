-- =============================================================================
-- ItemUnit_Add_RecentBaseCost -- schema change (run FIRST, before API deploy).
-- 2026-07-18 (PO pure-cost default, step 1). RecentCost is LANDED cost
--   (View_PurchaseHistory.TotalCost = BaseCost + LandedCostPerCase). POs need the
--   pure vendor cost, so store BaseCost alongside it as RecentBaseCost.
--   Written by ItemUnit_UpdateRecentCost; read by TempPurchaseService (PO cart
--   default) and DropShipment_* PO generation.
-- Plan: plan/po-item-base-cost-default-v2.md
-- =============================================================================
SET QUOTED_IDENTIFIER ON
GO

ALTER TABLE dbo.ItemUnit ADD RecentBaseCost DECIMAL(18, 4) NULL;
GO
