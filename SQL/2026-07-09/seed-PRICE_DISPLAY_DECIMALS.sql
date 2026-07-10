-- KLS-4DP-B-Phase2-Slice0: seed SystemSetting PRICE_DISPLAY_DECIMALS
-- 4-decimal pricing, Section B Phase-2, Slice 0 (config foundation).
-- Idempotent: inserts only if the key is absent (safe to re-run).
-- Default value '2' = current 2dp behavior -> INERT until an install opts into 4.
-- Allowed values: 2 or 4. Read in C# via SystemSettingService.GetByKey<int>(GlobalKey.PRICE_DISPLAY_DECIMALS),
-- and in SQL via SELECT SettingValue FROM SystemSetting WHERE SettingKey='PRICE_DISPLAY_DECIMALS' (mirrors ITEM_PRICE_ROUNDUP).
IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = 'PRICE_DISPLAY_DECIMALS')
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES ('PRICE_DISPLAY_DECIMALS', '2', 'int',
            'Unit-price decimal places for calculation and display. Allowed values 2 or 4. Default 2.',
            GETDATE());
END
GO
