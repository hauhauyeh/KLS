IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = 'PRODUCT_LIST_ITEMCODE_TOGGLE_ENABLE')
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'PRODUCT_LIST_ITEMCODE_TOGGLE_ENABLE',
        'false',
        'bool',
        'Enable Product List ItemCode click shortcut to toggle item active/inactive',
        SYSUTCDATETIME()
    );
END
ELSE
BEGIN
    UPDATE dbo.SystemSetting
    SET SettingValue = 'false'
    WHERE SettingKey = 'PRODUCT_LIST_ITEMCODE_TOGGLE_ENABLE';
END
