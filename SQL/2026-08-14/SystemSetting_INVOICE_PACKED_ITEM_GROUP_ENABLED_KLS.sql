SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Company
    WHERE UPPER(LTRIM(RTRIM(ISNULL(CompanyCode, '')))) = 'KLS'
)
BEGIN
    THROW 51000, 'This setting seed is only intended for KLS.', 1;
END
GO

IF EXISTS (
    SELECT 1
    FROM dbo.SystemSetting
    WHERE SettingKey = 'INVOICE_PACKED_ITEM_GROUP_ENABLED'
)
BEGIN
    UPDATE dbo.SystemSetting
    SET SettingValue = 'true',
        DataType = 'bool',
        Description = 'When true, invoice detail moves non-cs/non-lbs item lines under the PACKED ITEM group.',
        UpdatedAt = SYSUTCDATETIME()
    WHERE SettingKey = 'INVOICE_PACKED_ITEM_GROUP_ENABLED';
END
ELSE
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'INVOICE_PACKED_ITEM_GROUP_ENABLED',
        'true',
        'bool',
        'When true, invoice detail moves non-cs/non-lbs item lines under the PACKED ITEM group.',
        SYSUTCDATETIME()
    );
END
GO

SELECT SettingKey, SettingValue, DataType
FROM dbo.SystemSetting
WHERE SettingKey = 'INVOICE_PACKED_ITEM_GROUP_ENABLED';
GO
