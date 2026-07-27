-- =============================================================================================
-- Retire legacy single-match columns BankFeedTransaction.MatchedTxId / MatchedTxDetailId
--   (superseded by the BankFeedMatch junction table, created 2026-06-11).
--   Plan: plan/bank-feed-retire-legacy-matched-columns-v1.md
--
-- Apply order at deploy time:
--   1. BankFeed_UnMatchTx_update.sql   (SP must stop referencing the columns FIRST)
--   2. THIS script                     (drop FKs, rebuild index, drop columns)
--
-- Idempotent / guarded. Both columns are always NULL post-migration (verified 0 rows).
-- =============================================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- Safety: refuse to drop if any legacy value is still present (expected: none)
IF EXISTS (SELECT 1 FROM BankFeedTransaction WHERE MatchedTxId IS NOT NULL OR MatchedTxDetailId IS NOT NULL)
    THROW 50100, 'Legacy MatchedTxId/MatchedTxDetailId still hold data - investigate before dropping.', 1;
GO

-- 1. Drop the foreign keys that reference the legacy columns
IF OBJECT_ID('FK_BankFeedTransaction_TransactionJournal', 'F') IS NOT NULL
    ALTER TABLE BankFeedTransaction DROP CONSTRAINT FK_BankFeedTransaction_TransactionJournal;
IF OBJECT_ID('FK_BankFeedTransaction_TransactionJournalDetail', 'F') IS NOT NULL
    ALTER TABLE BankFeedTransaction DROP CONSTRAINT FK_BankFeedTransaction_TransactionJournalDetail;
GO

-- 2. Recreate the filter index WITHOUT the two legacy included columns
--    (unchanged key cols + included cols, minus MatchedTxId / MatchedTxDetailId)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BankFeedTransaction_Filter' AND object_id = OBJECT_ID('BankFeedTransaction'))
    DROP INDEX IX_BankFeedTransaction_Filter ON BankFeedTransaction;
GO
CREATE NONCLUSTERED INDEX IX_BankFeedTransaction_Filter
    ON BankFeedTransaction (BankFeedAccountId, Status, PostedDate, BankFeedTransactionId)
    INCLUDE (Amount, Description, ReferenceNo, CheckNumber);
GO

-- 3. Drop the columns
IF COL_LENGTH('BankFeedTransaction', 'MatchedTxId') IS NOT NULL
    ALTER TABLE BankFeedTransaction DROP COLUMN MatchedTxId;
IF COL_LENGTH('BankFeedTransaction', 'MatchedTxDetailId') IS NOT NULL
    ALTER TABLE BankFeedTransaction DROP COLUMN MatchedTxDetailId;
GO
