-- ============================================================================
-- Effort B / B1 (pulled forward as schema-only) -- add LandedCost to TransactionJournalDetail
-- Master plan: note-txdetail-itemunit-master-plan.md (Effort B, B1)
-- Design + rationale: note-billqty-live-db.md (finalized @INV column design)
-- ============================================================================
-- LandedCost = the freight/duty DOLLAR allocated to an inventory (@INV) line. It lets the finalized
-- model keep Price/BillQty ENTERED (exact value) and stop the two-phase Price mutation:
--     InventoryValue = Amount + LandedCost         (Amount = BillQty * Price = source line total)
--     AvgCost        = InventoryValue / Qty
--
-- INERT ON DEPLOY: nullable, NO writer/reader yet. Adding a NULLABLE column is metadata-only in SQL
-- Server (no table rewrite), so it is instant + zero-risk even on this ~2.6M-row table. Nothing consumes
-- it until Effort B is un-parked (B2 de-overload BillQty, B3 ReceiveQty landed allocation, B4 RecalcQAV
-- += Amount + LandedCost). Until then every row stays NULL and behavior is unchanged.
--
-- NOTE: this is a NEW column -- do NOT repurpose the vestigial TxDetail.FactorToBase (it is populated on
-- 2.58M rows and read live by the Inventory History "v" modal, ItemHistory_Inventory.FTB).
-- ============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.TransactionJournalDetail') AND name = 'LandedCost')
BEGIN
    ALTER TABLE dbo.TransactionJournalDetail
        ADD LandedCost DECIMAL(18, 6) NULL;
END
GO
