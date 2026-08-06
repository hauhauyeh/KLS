SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF DB_NAME() NOT IN ('KLS_2026', 'GUS_2026')
BEGIN
    THROW 51000, 'Wrong database for SALES_TRANSIT_UPDATE_DOCUMENT_ACTION seed.', 1;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SystemSetting
    WHERE SettingKey = 'SALES_TRANSIT_UPDATE_DOCUMENT_ACTION'
)
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'SALES_TRANSIT_UPDATE_DOCUMENT_ACTION',
        'Print',
        'string',
        'Action offered after editing a Sales order that was previously in Transit. Allowed values: Print, Email, None.',
        SYSUTCDATETIME()
    );
END
GO

-- GUS should use email instead of print for revised invoice resend:
-- UPDATE dbo.SystemSetting
-- SET SettingValue = 'Email'
-- WHERE SettingKey = 'SALES_TRANSIT_UPDATE_DOCUMENT_ACTION';
-- GO
