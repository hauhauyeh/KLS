-- ItemQuote Manager Phase 4A schema guardrails.
-- Purpose: prevent duplicate customer quote rows per item/unit in saved and draft quote tables.
-- Deploy only after Howard approval.

SET XACT_ABORT ON;

IF EXISTS (
    SELECT 1
    FROM dbo.ItemQuote
    GROUP BY PayeeId, ItemUnitId
    HAVING COUNT(*) > 1
)
    THROW 51000, 'Cannot create UX_ItemQuote_PayeeId_ItemUnitId: duplicate ItemQuote PayeeId + ItemUnitId rows exist.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.TempItemQuote
    GROUP BY EmpId, PayeeId, ItemUnitId
    HAVING COUNT(*) > 1
)
    THROW 51001, 'Cannot create UX_TempItemQuote_EmpId_PayeeId_ItemUnitId: duplicate TempItemQuote EmpId + PayeeId + ItemUnitId rows exist.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.ItemQuote') AND name = 'UX_ItemQuote_PayeeId_ItemUnitId')
    CREATE UNIQUE INDEX UX_ItemQuote_PayeeId_ItemUnitId
    ON dbo.ItemQuote(PayeeId, ItemUnitId);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TempItemQuote') AND name = 'UX_TempItemQuote_EmpId_PayeeId_ItemUnitId')
    CREATE UNIQUE INDEX UX_TempItemQuote_EmpId_PayeeId_ItemUnitId
    ON dbo.TempItemQuote(EmpId, PayeeId, ItemUnitId);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.ItemQuote') AND name = 'IX_ItemQuote_PayeeId_ItemId')
    CREATE INDEX IX_ItemQuote_PayeeId_ItemId
    ON dbo.ItemQuote(PayeeId, ItemId);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.TempItemQuote') AND name = 'IX_TempItemQuote_EmpId_PayeeId_ItemId')
    CREATE INDEX IX_TempItemQuote_EmpId_PayeeId_ItemId
    ON dbo.TempItemQuote(EmpId, PayeeId, ItemId);
