SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- SalesQuote_SalesQuoteType_rollback
-- Removes the SalesQuoteType constraints and column.

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.SalesQuote')
      AND name = 'CK_SalesQuote_SalesQuoteType'
)
BEGIN
    ALTER TABLE dbo.SalesQuote
        DROP CONSTRAINT CK_SalesQuote_SalesQuoteType;
END
GO

IF EXISTS
(
    SELECT 1
    FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.SalesQuote')
      AND name = 'DF_SalesQuote_SalesQuoteType'
)
BEGIN
    ALTER TABLE dbo.SalesQuote
        DROP CONSTRAINT DF_SalesQuote_SalesQuoteType;
END
GO

IF COL_LENGTH('dbo.SalesQuote', 'SalesQuoteType') IS NOT NULL
BEGIN
    ALTER TABLE dbo.SalesQuote
        DROP COLUMN SalesQuoteType;
END
GO
