/*
Slice 1 - SalesDocNumber schema and display flag.

Behavior change: none. Display flag is seeded off.
Rollback: 01-SalesDocNumber_Schema_rollback.sql
*/

SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF COL_LENGTH('dbo.Sales', 'SalesDocNumber') IS NULL
BEGIN
    EXEC(N'ALTER TABLE dbo.Sales ADD SalesDocNumber NVARCHAR(50) NULL;');
END;

IF OBJECT_ID('dbo.SalesDocNumberCounter', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SalesDocNumberCounter (
        DocDate DATE NOT NULL,
        LastSeq INT NOT NULL,
        UpdatedAt DATETIME2 NOT NULL CONSTRAINT DF_SalesDocNumberCounter_UpdatedAt DEFAULT GETUTCDATE(),
        CONSTRAINT PK_SalesDocNumberCounter PRIMARY KEY (DocDate)
    );
END;

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Sales')
      AND name = 'UX_Sales_SalesDocNumber'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX UX_Sales_SalesDocNumber
        ON dbo.Sales(SalesDocNumber)
        WHERE SalesDocNumber IS NOT NULL;');
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SystemSetting
    WHERE SettingKey = 'SALES_DOC_NUMBER_DISPLAY_ENABLED'
)
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'SALES_DOC_NUMBER_DISPLAY_ENABLED',
        'false',
        'bool',
        'Enables customer-facing display of SalesDocNumber when a Sales row has one.',
        GETDATE()
    );
END;

COMMIT TRANSACTION;
