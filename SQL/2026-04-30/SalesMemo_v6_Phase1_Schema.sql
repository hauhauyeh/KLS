SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Phase 1 (v6) schema

Adds only the minimal fields needed for the v6 design:
- Sales.ParentSalesNumber
- Sales.DocType
- TempSales.ParentSalesNumber

No suffix/display-number schema is introduced.
*/

IF COL_LENGTH('dbo.Sales', 'ParentSalesNumber') IS NULL
BEGIN
    ALTER TABLE dbo.Sales
        ADD ParentSalesNumber INT NULL;
END
GO

IF COL_LENGTH('dbo.Sales', 'DocType') IS NULL
BEGIN
    ALTER TABLE dbo.Sales
        ADD DocType CHAR(2) NULL;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_Sales_DocType'
      AND parent_object_id = OBJECT_ID('dbo.Sales')
)
BEGIN
    ALTER TABLE dbo.Sales
        ADD CONSTRAINT CK_Sales_DocType
        CHECK (DocType IN ('SO', 'CM', 'DM'));
END
GO

-- Existing rows are legacy sales orders unless explicitly changed later.
UPDATE dbo.Sales
SET DocType = 'SO'
WHERE DocType IS NULL;
GO

IF EXISTS (
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.Sales')
      AND name = 'DocType'
      AND is_nullable = 1
)
BEGIN
    ALTER TABLE dbo.Sales
        ALTER COLUMN DocType CHAR(2) NOT NULL;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.Sales')
      AND name = 'DF_Sales_DocType'
)
BEGIN
    ALTER TABLE dbo.Sales
        ADD CONSTRAINT DF_Sales_DocType
        DEFAULT ('SO') FOR DocType;
END
GO

IF COL_LENGTH('dbo.TempSales', 'ParentSalesNumber') IS NULL
BEGIN
    ALTER TABLE dbo.TempSales
        ADD ParentSalesNumber INT NULL;
END
GO
