IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = 'SALES_LOAD_SEPARATE')
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'SALES_LOAD_SEPARATE',
        'true',
        'bool',
        'Enable Load Separate action in Order Manager',
        SYSUTCDATETIME()
    );
END
