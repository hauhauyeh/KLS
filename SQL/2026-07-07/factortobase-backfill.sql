-- =============================================================================
-- factortobase-backfill.sql  (Effort-B, authored 2026-07-07 -- ASK before deploy)
-- Backfill historical @INV journal FactorToBase (unit ratio) -> EntQty (entered
-- physical qty), matching the deployed writers:
--   Sales / Sales Credit Memo @INV -> SalesDetail.ShipQty
--   Purchase                  @INV -> PurchaseDetail.ReceiveQty
-- @INV rows ONLY; FactorToBase column ONLY (NOT BillQty/Qty/Price). Audit-slot,
-- consumer-free. Backs up ONLY rows that change; batched (per-batch autocommit);
-- reversible via factortobase-backfill_rollback.sql.
-- =============================================================================
USE [KLS_2026];
GO
SET NOCOUNT ON;
GO

DECLARE @INV INT = (SELECT AccountId FROM dbo.Account WHERE AccountCode = '@INV');
IF @INV IS NULL
BEGIN
    RAISERROR('@INV account not found.', 16, 1);
    RETURN;
END

-- ---- Preflight: coverage guard -- abort if any @INV row has a SourceDocType we
--      neither backfill (sales/purchase) nor intentionally skip (base-native/non-item).
--      Catches Sales/Purchase Debit Memo (now handled) + any future/unexpected type,
--      so no inventory row is silently left on old ratio basis. (0 today.)
DECLARE @unhandled INT = (
    SELECT COUNT(*)
    FROM dbo.TransactionJournalDetail td
    JOIN dbo.TransactionJournal tj ON tj.TxId = td.TxId
    WHERE td.AccountId = @INV
      AND tj.SourceDocType NOT IN (
            'Sales', 'Sales Credit Memo', 'Sales Debit Memo',          -- backfilled -> ShipQty
            'Purchase', 'Purchase Debit Memo',                          -- backfilled -> ReceiveQty
            'Inventory Adj', 'Inventory Adj Closing',                   -- base-native (no unit source) -> skip
            'General Journal', 'Check'                                  -- non-item @INV -> skip
          )
);
IF @unhandled > 0
BEGIN
    RAISERROR('Backfill aborted: %d @INV rows have an UNHANDLED SourceDocType -- route it (sales/purchase) or add to the skip list before running.', 16, 1, @unhandled);
    RETURN;
END

-- ---- Preflight: backup table must NOT already exist (rerun guard) -----------
IF OBJECT_ID('dbo._FactorToBase_backfill_backup_2026_07_07') IS NOT NULL
BEGIN
    RAISERROR('Backup table dbo._FactorToBase_backfill_backup_2026_07_07 already exists -- backfill may already have run. Run the rollback (or drop the table) before re-running.', 16, 1);
    RETURN;
END

-- ---- Backup table: ONLY rows that will actually change ----------------------
CREATE TABLE dbo._FactorToBase_backfill_backup_2026_07_07
(
    TxDetailId       BIGINT        NOT NULL PRIMARY KEY,
    SourceDocType    NVARCHAR(100) NULL,
    OldFactorToBase  DECIMAL(18,6) NULL,
    NewFactorToBase  DECIMAL(18,6) NULL
);

-- Sales + Sales Credit Memo @INV -> ShipQty  (INNER JOIN skips orphans)
INSERT INTO dbo._FactorToBase_backfill_backup_2026_07_07 (TxDetailId, SourceDocType, OldFactorToBase, NewFactorToBase)
SELECT td.TxDetailId, tj.SourceDocType, td.FactorToBase, sd.ShipQty
FROM dbo.TransactionJournalDetail td
JOIN dbo.TransactionJournal   tj ON tj.TxId = td.TxId
JOIN dbo.SalesDetail          sd ON sd.SalesDetailId = td.SourceDetailId
WHERE td.AccountId = @INV
  AND tj.SourceDocType IN ('Sales', 'Sales Credit Memo', 'Sales Debit Memo')
  AND td.FactorToBase <> sd.ShipQty;

-- Purchase @INV -> ReceiveQty
INSERT INTO dbo._FactorToBase_backfill_backup_2026_07_07 (TxDetailId, SourceDocType, OldFactorToBase, NewFactorToBase)
SELECT td.TxDetailId, tj.SourceDocType, td.FactorToBase, pd.ReceiveQty
FROM dbo.TransactionJournalDetail td
JOIN dbo.TransactionJournal   tj ON tj.TxId = td.TxId
JOIN dbo.PurchaseDetail       pd ON pd.PurchaseDetailId = td.SourceDetailId
WHERE td.AccountId = @INV
  AND tj.SourceDocType IN ('Purchase', 'Purchase Debit Memo')
  AND td.FactorToBase <> pd.ReceiveQty;

DECLARE @backupCount INT = (SELECT COUNT(*) FROM dbo._FactorToBase_backfill_backup_2026_07_07);
PRINT 'Backup rows (will change): ' + CAST(@backupCount AS varchar(20));

-- ---- Batched UPDATE from backup (TOP 50000; per-batch autocommit; resumable) -
DECLARE @rows INT = 1, @total BIGINT = 0;
WHILE @rows > 0
BEGIN
    UPDATE TOP (50000) td
    SET td.FactorToBase = b.NewFactorToBase
    FROM dbo.TransactionJournalDetail td
    JOIN dbo._FactorToBase_backfill_backup_2026_07_07 b ON b.TxDetailId = td.TxDetailId
    WHERE td.FactorToBase <> b.NewFactorToBase;
    SET @rows = @@ROWCOUNT;
    SET @total += @rows;
END
PRINT 'Rows updated: ' + CAST(@total AS varchar(20));
GO

-- ---- Post-update validation (split Sales / Purchase) ------------------------
DECLARE @INV INT = (SELECT AccountId FROM dbo.Account WHERE AccountCode = '@INV');

-- (a) changed counts by source (from backup)
SELECT SourceGroup = CASE WHEN SourceDocType LIKE 'Purchase%' THEN 'PURCHASE' ELSE 'SALES' END,
       Changed     = COUNT(*)
FROM dbo._FactorToBase_backfill_backup_2026_07_07
GROUP BY CASE WHEN SourceDocType LIKE 'Purchase%' THEN 'PURCHASE' ELSE 'SALES' END;

-- (b) orphans skipped (measured; not backfilled)
SELECT Metric = 'SALES orphans skipped (no SalesDetail)', Cnt = COUNT(*)
FROM dbo.TransactionJournalDetail td
JOIN dbo.TransactionJournal tj ON tj.TxId = td.TxId
LEFT JOIN dbo.SalesDetail sd ON sd.SalesDetailId = td.SourceDetailId
WHERE td.AccountId = @INV AND tj.SourceDocType IN ('Sales', 'Sales Credit Memo', 'Sales Debit Memo') AND sd.SalesDetailId IS NULL
UNION ALL
SELECT 'PURCHASE orphans skipped (no PurchaseDetail)', COUNT(*)
FROM dbo.TransactionJournalDetail td
JOIN dbo.TransactionJournal tj ON tj.TxId = td.TxId
LEFT JOIN dbo.PurchaseDetail pd ON pd.PurchaseDetailId = td.SourceDetailId
WHERE td.AccountId = @INV AND tj.SourceDocType IN ('Purchase', 'Purchase Debit Memo') AND pd.PurchaseDetailId IS NULL;

-- (c) MISMATCH after backfill (MUST be 0): @INV rows with a source whose FactorToBase <> source qty
SELECT Metric = 'SALES mismatch (FTB <> ShipQty)', Cnt = COUNT(*)
FROM dbo.TransactionJournalDetail td
JOIN dbo.TransactionJournal tj ON tj.TxId = td.TxId
JOIN dbo.SalesDetail sd ON sd.SalesDetailId = td.SourceDetailId
WHERE td.AccountId = @INV AND tj.SourceDocType IN ('Sales', 'Sales Credit Memo', 'Sales Debit Memo') AND td.FactorToBase <> sd.ShipQty
UNION ALL
SELECT 'PURCHASE mismatch (FTB <> ReceiveQty)', COUNT(*)
FROM dbo.TransactionJournalDetail td
JOIN dbo.TransactionJournal tj ON tj.TxId = td.TxId
JOIN dbo.PurchaseDetail pd ON pd.PurchaseDetailId = td.SourceDetailId
WHERE td.AccountId = @INV AND tj.SourceDocType IN ('Purchase', 'Purchase Debit Memo') AND td.FactorToBase <> pd.ReceiveQty;
GO
