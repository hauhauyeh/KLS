IF NOT EXISTS (SELECT 1 FROM SystemSetting WHERE SettingKey = 'WEB_ORDER_CHECKOUT_HOUR')
BEGIN
    INSERT INTO SystemSetting (SettingKey, SettingValue, DataType, Description)
    VALUES ('WEB_ORDER_CHECKOUT_HOUR', '2', 'int',
            'Checkout cutoff hour for web portal. Orders placed after this hour ship the next business day.');
END
