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
    THROW 51000, 'This setting rollback is only intended for KLS.', 1;
END
GO

DELETE FROM dbo.SystemSetting
WHERE SettingKey = 'INVOICE_PACKED_ITEM_GROUP_ENABLED';
GO
