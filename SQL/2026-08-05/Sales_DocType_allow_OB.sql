-- 2026-08-05 Slice 0: allow opening-balance Sales headers.
-- Purpose: permit Sales.DocType = 'OB' so OpenBalance_Import can create
-- header-only opening AR source rows without using normal Sales_Insert.

SET XACT_ABORT ON;

BEGIN TRAN;

IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
    WHERE c.object_id = OBJECT_ID('dbo.Sales')
      AND c.name = 'DocType'
      AND t.name = 'char'
      AND c.max_length = 2
)
    THROW 51000, 'Expected dbo.Sales.DocType to be char(2). Stop before changing CK_Sales_DocType.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.Sales')
      AND name = 'CK_Sales_DocType'
      AND definition = '([DocType]=''DM'' OR [DocType]=''CM'' OR [DocType]=''SO'')'
)
    THROW 51001, 'Expected CK_Sales_DocType to allow only DM, CM, SO. Capture a new baseline before deploying.', 1;

ALTER TABLE dbo.Sales DROP CONSTRAINT CK_Sales_DocType;

ALTER TABLE dbo.Sales WITH CHECK ADD CONSTRAINT CK_Sales_DocType
CHECK ([DocType] = 'DM' OR [DocType] = 'CM' OR [DocType] = 'SO' OR [DocType] = 'OB');

ALTER TABLE dbo.Sales CHECK CONSTRAINT CK_Sales_DocType;

COMMIT;
