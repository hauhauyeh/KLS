SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- SalesQuote_SalesQuoteType
-- Adds the SalesQuote header type discriminator used by quote CRUD.
-- Existing and omitted values default to NormalSalesQuote.

IF COL_LENGTH('dbo.SalesQuote', 'SalesQuoteType') IS NULL
BEGIN
    ALTER TABLE dbo.SalesQuote
        ADD SalesQuoteType NVARCHAR(30) NULL;
END
GO

UPDATE dbo.SalesQuote
SET SalesQuoteType = 'NormalSalesQuote'
WHERE SalesQuoteType IS NULL
   OR LTRIM(RTRIM(SalesQuoteType)) = '';
GO

IF EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.SalesQuote')
      AND name = 'SalesQuoteType'
      AND is_nullable = 1
)
BEGIN
    ALTER TABLE dbo.SalesQuote
        ALTER COLUMN SalesQuoteType NVARCHAR(30) NOT NULL;
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.SalesQuote')
      AND name = 'DF_SalesQuote_SalesQuoteType'
)
BEGIN
    ALTER TABLE dbo.SalesQuote
        ADD CONSTRAINT DF_SalesQuote_SalesQuoteType
        DEFAULT ('NormalSalesQuote') FOR SalesQuoteType;
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.SalesQuote')
      AND name = 'CK_SalesQuote_SalesQuoteType'
)
BEGIN
    ALTER TABLE dbo.SalesQuote
        ADD CONSTRAINT CK_SalesQuote_SalesQuoteType
        CHECK (SalesQuoteType IN ('NormalSalesQuote', 'DropShipSalesQuote', 'PriceProposal'));
END
GO
