IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = 'INTERCOMPANY_ITEM_SYNC_ENABLED')
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'INTERCOMPANY_ITEM_SYNC_ENABLED',
        'false',
        'bool',
        'Enable intercompany item, category, storage, and image sync tools for this database',
        SYSUTCDATETIME()
    );
END

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = 'INTERCOMPANY_SALES_TRANSFER_ENABLED')
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'INTERCOMPANY_SALES_TRANSFER_ENABLED',
        'false',
        'bool',
        'Enable intercompany sales transfer tools for this database',
        SYSUTCDATETIME()
    );
END
