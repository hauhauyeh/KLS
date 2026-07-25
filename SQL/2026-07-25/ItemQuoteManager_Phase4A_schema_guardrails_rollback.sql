-- Rollback for ItemQuote Manager Phase 4A schema guardrails.
-- Drops only the exact indexes added by ItemQuoteManager_Phase4A_schema_guardrails.sql.
-- Deploy only after Howard approval.

IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TempItemQuote') AND name = 'IX_TempItemQuote_EmpId_PayeeId_ItemId')
    DROP INDEX IX_TempItemQuote_EmpId_PayeeId_ItemId ON dbo.TempItemQuote;

IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.ItemQuote') AND name = 'IX_ItemQuote_PayeeId_ItemId')
    DROP INDEX IX_ItemQuote_PayeeId_ItemId ON dbo.ItemQuote;

IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TempItemQuote') AND name = 'UX_TempItemQuote_EmpId_PayeeId_ItemUnitId')
    DROP INDEX UX_TempItemQuote_EmpId_PayeeId_ItemUnitId ON dbo.TempItemQuote;

IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.ItemQuote') AND name = 'UX_ItemQuote_PayeeId_ItemUnitId')
    DROP INDEX UX_ItemQuote_PayeeId_ItemUnitId ON dbo.ItemQuote;
