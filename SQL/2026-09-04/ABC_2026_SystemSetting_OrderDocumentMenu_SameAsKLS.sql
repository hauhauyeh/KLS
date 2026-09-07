-- ============================================================
-- ABC_2026_SystemSetting_OrderDocumentMenu_SameAsKLS  (2026-09-04)
--
-- Make ABC's Order Manager document/print menu behave like KLS.
-- KLS-2026 stores SALES_ORDER_DOCUMENT_MENU_JSON = NULL. The Angular resolver
-- (sales-order-document-menu-config.ts) treats NULL / empty / invalid JSON as
-- "full default menu": Print Invoice, Print Pick Ticket, Print Packing List,
-- all Gen/Email actions, and every batch route action.
-- Any JSON value restricts single-order actions to the keys it lists and
-- drops batch actions unless a "batch" section is present.
--
-- Data only, one row. Rollback: restore the value shown by the SELECT below.
-- Deploy: sqlcmd -S RAJNI\SQLEXPRESS -d ABC_2026 -C -b -i ABC_2026_SystemSetting_OrderDocumentMenu_SameAsKLS.sql
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;

DECLARE @CompanyCode NVARCHAR(40);
SELECT TOP (1) @CompanyCode = CompanyCode FROM dbo.Company;
IF ISNULL(UPPER(LTRIM(RTRIM(@CompanyCode))), '') <> 'ABC'
    THROW 51000, 'This script is only intended for the ABC company database.', 1;

-- Before (keep this output as the rollback value)
SELECT Id, SettingKey, SettingValue AS BeforeValue, DataType, Description, UpdatedAt
FROM dbo.SystemSetting
WHERE SettingKey = N'SALES_ORDER_DOCUMENT_MENU_JSON';

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = N'SALES_ORDER_DOCUMENT_MENU_JSON')
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (N'SALES_ORDER_DOCUMENT_MENU_JSON', NULL, N'json',
            N'Order Manager document/print menu configuration.', SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE dbo.SystemSetting
    SET SettingValue = NULL,            -- same as KLS-2026: full default menu
        DataType     = N'json',
        Description  = N'Order Manager document/print menu configuration.',
        UpdatedAt    = SYSUTCDATETIME()
    WHERE SettingKey = N'SALES_ORDER_DOCUMENT_MENU_JSON';
END

-- After
SELECT Id, SettingKey, SettingValue AS AfterValue, DataType, Description, UpdatedAt
FROM dbo.SystemSetting
WHERE SettingKey = N'SALES_ORDER_DOCUMENT_MENU_JSON';
GO
