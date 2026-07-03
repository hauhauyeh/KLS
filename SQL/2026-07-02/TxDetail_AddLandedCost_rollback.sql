-- ============================================================================
-- Rollback -- remove LandedCost from TransactionJournalDetail
-- Reverses TxDetail_AddLandedCost.sql. Safe while Effort B is parked (column is inert / all NULL).
-- Do NOT run once B2/B3/B4 populate it (rows would hold real freight dollars).
-- ============================================================================

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.TransactionJournalDetail') AND name = 'LandedCost')
    ALTER TABLE dbo.TransactionJournalDetail DROP COLUMN LandedCost;
GO
