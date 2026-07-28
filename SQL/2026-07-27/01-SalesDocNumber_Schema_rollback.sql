/*
Rollback for Slice 1 - SalesDocNumber schema and display flag.

Drops only objects/settings introduced by 01-SalesDocNumber_Schema.sql.
*/

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Sales')
      AND name = 'UX_Sales_SalesDocNumber'
)
BEGIN
    DROP INDEX UX_Sales_SalesDocNumber ON dbo.Sales;
END;

IF OBJECT_ID('dbo.SalesDocNumberCounter', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.SalesDocNumberCounter;
END;

IF COL_LENGTH('dbo.Sales', 'SalesDocNumber') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Sales
        DROP COLUMN SalesDocNumber;
END;

DELETE FROM dbo.SystemSetting
WHERE SettingKey IN (
    'SALES_DOC_NUMBER_DISPLAY_ENABLED'
);

COMMIT TRANSACTION;
