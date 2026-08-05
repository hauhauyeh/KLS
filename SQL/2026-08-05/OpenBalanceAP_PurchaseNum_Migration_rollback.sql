-- 2026-08-05 rollback for OpenBalanceAP_PurchaseNum_Migration.sql
--
-- Restores dbo.OpenBalanceAP.PurchaseNum to INT and clears the PurchaseId
-- links the migration wrote.
--
-- The order is the whole point. After the migration 29 of the 166 rows hold
-- non-numeric values such as AR29915 or 5274488-001, so altering straight back
-- to INT would fail. The snapshot is restored FIRST, which makes every value
-- numeric again, and only then does the column change type.
--
-- This rollback is only valid while the snapshot still describes the table.
-- Once a real AP import has run, the snapshot is stale and this script refuses
-- to run rather than overwriting imported data. At that point rolling back is a
-- data decision, not a script.

SET XACT_ABORT ON;
GO

BEGIN TRAN;

------------------------------------------------------------------
-- Guards, all before anything is written.
------------------------------------------------------------------

IF OBJECT_ID('dbo.OpenBalanceAP_PurchaseNum_Backup_20260805') IS NULL
    THROW 51110, 'Backup table is missing. Cannot roll back without the original values.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
    WHERE c.object_id = OBJECT_ID('dbo.OpenBalanceAP')
      AND c.name = 'PurchaseNum'
      AND t.name = 'nvarchar'
)
    THROW 51111, 'PurchaseNum is not nvarchar. The forward migration does not appear to be in effect.', 1;

-- A row count mismatch, or any row the snapshot does not know about, means an
-- import has run since the migration.
IF (SELECT COUNT(*) FROM dbo.OpenBalanceAP)
   <> (SELECT COUNT(*) FROM dbo.OpenBalanceAP_PurchaseNum_Backup_20260805)
    THROW 51112, 'OpenBalanceAP row count no longer matches the snapshot. An import has run since the migration; roll back by hand.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.OpenBalanceAP o
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.OpenBalanceAP_PurchaseNum_Backup_20260805 b
        WHERE b.OpenAPId = o.OpenAPId
    )
)
    THROW 51113, 'OpenBalanceAP contains rows the snapshot does not cover. An import has run since the migration; roll back by hand.', 1;

------------------------------------------------------------------
-- 1. Restore the original integers as text. This is what makes the
--    ALTER back to INT possible.
------------------------------------------------------------------

UPDATE o
SET o.PurchaseNum = CONVERT(NVARCHAR(200), b.OldPurchaseNum)
FROM dbo.OpenBalanceAP o
JOIN dbo.OpenBalanceAP_PurchaseNum_Backup_20260805 b
    ON b.OpenAPId = o.OpenAPId;

------------------------------------------------------------------
-- 2. Undo the adoption. Restores whatever PurchaseId each row had
--    before, which on the captured baseline was NULL everywhere.
------------------------------------------------------------------

UPDATE o
SET o.PurchaseId = b.OldPurchaseId
FROM dbo.OpenBalanceAP o
JOIN dbo.OpenBalanceAP_PurchaseNum_Backup_20260805 b
    ON b.OpenAPId = o.OpenAPId;

------------------------------------------------------------------
-- 3. Last check before the type change: nothing non-numeric may be
--    left, or the ALTER fails and takes the transaction with it.
------------------------------------------------------------------

IF EXISTS (
    SELECT 1
    FROM dbo.OpenBalanceAP
    WHERE PurchaseNum IS NOT NULL
      AND TRY_CONVERT(INT, PurchaseNum) IS NULL
)
    THROW 51114, 'A non-numeric PurchaseNum survived the restore. Stop; the snapshot does not cover current data.', 1;

GO

ALTER TABLE dbo.OpenBalanceAP ALTER COLUMN PurchaseNum INT NULL;
GO

COMMIT;
GO

-- The backup table is deliberately left in place. Drop it only once the
-- rollback has been verified:
--   DROP TABLE dbo.OpenBalanceAP_PurchaseNum_Backup_20260805;

SELECT
    COUNT(*)            AS RowCnt,
    COUNT(PurchaseNum)  AS PurchaseNumNotNull,
    COUNT(PurchaseId)   AS PurchaseIdNotNull
FROM dbo.OpenBalanceAP;
GO
