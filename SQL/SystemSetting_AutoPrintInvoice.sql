-- Add AUTO_PRINTINVOICE setting
IF NOT EXISTS (SELECT 1 FROM SystemSetting WHERE SettingKey = 'AUTO_PRINTINVOICE')
    INSERT INTO SystemSetting (SettingKey, SettingValue) VALUES ('AUTO_PRINTINVOICE', 'false');
