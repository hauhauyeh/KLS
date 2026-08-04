IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = 'WEB_PUBLIC_PRODUCT_LIST_ENABLE')
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'WEB_PUBLIC_PRODUCT_LIST_ENABLE',
        'false',
        'bool',
        'Allow web portal visitors to browse product catalog before login without pricing or ordering',
        SYSUTCDATETIME()
    );
END
