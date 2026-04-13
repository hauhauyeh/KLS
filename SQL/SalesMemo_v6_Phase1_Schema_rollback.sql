SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Phase 1 (v6) schema rollback

Removes:
- Sales.ParentSalesNumber
- Sales.DocType
- TempSales.ParentSalesNumber
*/

IF EXISTS (
    SELECT 1
    FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.Sales')
      AND name = 'DF_Sales_DocType'
)
BEGIN
    ALTER TABLE dbo.Sales
        DROP CONSTRAINT DF_Sales_DocType;
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = 'CK_Sales_DocType'
      AND parent_object_id = OBJECT_ID('dbo.Sales')
)
BEGIN
    ALTER TABLE dbo.Sales
        DROP CONSTRAINT CK_Sales_DocType;
END
GO

IF COL_LENGTH('dbo.TempSales', 'ParentSalesNumber') IS NOT NULL
BEGIN
    ALTER TABLE dbo.TempSales
        DROP COLUMN ParentSalesNumber;
END
GO

IF COL_LENGTH('dbo.Sales', 'ParentSalesNumber') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Sales
        DROP COLUMN ParentSalesNumber;
END
GO

IF COL_LENGTH('dbo.Sales', 'DocType') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Sales
        DROP COLUMN DocType;
END
GO
