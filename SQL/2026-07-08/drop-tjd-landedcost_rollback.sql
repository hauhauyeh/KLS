-- =============================================================================
-- drop-tjd-landedcost_rollback.sql
-- Reverse drop-tjd-landedcost.sql: re-add the inert column exactly as it was
-- (DECIMAL(18,6) NULL, no default). Re-added all-NULL -- there is no data to
-- restore (the column was all-NULL when dropped).
-- =============================================================================
USE [KLS_2026];
GO
SET NOCOUNT ON;
GO

IF COL_LENGTH('dbo.TransactionJournalDetail', 'LandedCost') IS NOT NULL
BEGIN
    PRINT 'TransactionJournalDetail.LandedCost already present -- nothing to re-add.';
    RETURN;
END

ALTER TABLE dbo.TransactionJournalDetail ADD LandedCost DECIMAL(18,6) NULL;
PRINT 'Re-added TransactionJournalDetail.LandedCost (inert, all-NULL).';
GO
