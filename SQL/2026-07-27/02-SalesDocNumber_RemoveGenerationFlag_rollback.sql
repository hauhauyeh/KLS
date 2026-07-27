/*
Rollback for SalesDocNumber generation-flag cleanup.
*/

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SystemSetting
    WHERE SettingKey = 'SALES_DOC_NUMBER_ENABLED'
)
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'SALES_DOC_NUMBER_ENABLED',
        'false',
        'bool',
        'Enables customer-facing SalesDocNumber generation for new Sales rows.',
        GETDATE()
    );
END;

