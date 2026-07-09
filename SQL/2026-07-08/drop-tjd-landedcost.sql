-- =============================================================================
-- drop-tjd-landedcost.sql   (Effort-B step 8 -- ASK before deploy)
-- DROP the unused column dbo.TransactionJournalDetail.LandedCost.
--
-- Added inert 2026-07-02; the 2026-07-07 model keeps landed baked in Price, so it
-- never gained a writer. Precheck 2026-07-08: all-NULL (0 / 2,630,652 rows); no
-- index/constraint/computed-col/view dependency; only Shipment_AllocationInventoryClear
-- mentions "LandedCost" and that is the SOURCE pd.LandedCost (via #TxImpact), NOT this
-- journal column; unmapped in EF (no LandedCost on any Transaction* model).
-- Rollback: drop-tjd-landedcost_rollback.sql (re-adds inert).
-- =============================================================================
USE [KLS_2026];
GO
SET NOCOUNT ON;
GO

IF COL_LENGTH('dbo.TransactionJournalDetail', 'LandedCost') IS NULL
BEGIN
    PRINT 'TransactionJournalDetail.LandedCost already absent -- nothing to drop.';
    RETURN;
END

-- Safety: never drop if any row carries data (guards against a writer having appeared).
IF EXISTS (SELECT 1 FROM dbo.TransactionJournalDetail WHERE LandedCost IS NOT NULL)
BEGIN
    RAISERROR('ABORT: TransactionJournalDetail.LandedCost has NON-NULL values -- investigate before dropping.', 16, 1);
    RETURN;
END

ALTER TABLE dbo.TransactionJournalDetail DROP COLUMN LandedCost;
PRINT 'Dropped TransactionJournalDetail.LandedCost.';
GO

-- assert
IF COL_LENGTH('dbo.TransactionJournalDetail', 'LandedCost') IS NULL
    PRINT 'CONFIRMED: TransactionJournalDetail.LandedCost is gone.';
ELSE
    RAISERROR('LandedCost still present after drop -- check the error above.', 16, 1);
GO
