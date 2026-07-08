-- =============================================================================
-- factortobase-backfill_rollback.sql  (Effort-B, authored 2026-07-07)
-- Reverse factortobase-backfill.sql: restore @INV FactorToBase to the exact
-- pre-backfill values from the backup table (batched). Requires the backup table
-- dbo._FactorToBase_backfill_backup_2026_07_07 to still exist.
-- =============================================================================
USE [KLS_2026];
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo._FactorToBase_backfill_backup_2026_07_07') IS NULL
BEGIN
    RAISERROR('Backup table dbo._FactorToBase_backfill_backup_2026_07_07 not found -- nothing to roll back from.', 16, 1);
    RETURN;
END

-- ---- Batched RESTORE from backup (TOP 50000; per-batch autocommit; resumable) -
DECLARE @rows INT = 1, @total BIGINT = 0;
WHILE @rows > 0
BEGIN
    UPDATE TOP (50000) td
    SET td.FactorToBase = b.OldFactorToBase
    FROM dbo.TransactionJournalDetail td
    JOIN dbo._FactorToBase_backfill_backup_2026_07_07 b ON b.TxDetailId = td.TxDetailId
    WHERE NOT (td.FactorToBase = b.OldFactorToBase)      -- NULL-safe-ish; backup Old is non-NULL for these rows
       OR (td.FactorToBase IS NULL AND b.OldFactorToBase IS NOT NULL);
    SET @rows = @@ROWCOUNT;
    SET @total += @rows;
END
PRINT 'Rows restored: ' + CAST(@total AS varchar(20));

-- ---- Validation: every backup row is back to OldFactorToBase (MUST be 0) ------
SELECT Metric = 'rows NOT yet restored (should be 0)', Cnt = COUNT(*)
FROM dbo.TransactionJournalDetail td
JOIN dbo._FactorToBase_backfill_backup_2026_07_07 b ON b.TxDetailId = td.TxDetailId
WHERE td.FactorToBase <> b.OldFactorToBase;
GO

-- ---- Final cleanup: drop the backup table ONLY after confirming the restore. --
-- Uncomment to drop once the validation above shows 0:
-- DROP TABLE dbo._FactorToBase_backfill_backup_2026_07_07;
-- GO
