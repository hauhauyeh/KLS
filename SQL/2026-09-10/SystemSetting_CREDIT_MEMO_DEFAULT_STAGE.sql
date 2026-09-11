SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SystemSetting
    WHERE SettingKey = 'CREDIT_MEMO_DEFAULT_STAGE'
)
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'CREDIT_MEMO_DEFAULT_STAGE',
        '4',
        'int',
        'Default sales stage for newly created credit memos. 0 = Order, 4 = Success.',
        SYSUTCDATETIME()
    );
END
GO

SELECT SettingKey, SettingValue, DataType
FROM dbo.SystemSetting
WHERE SettingKey = 'CREDIT_MEMO_DEFAULT_STAGE';
GO
