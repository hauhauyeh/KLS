-- ============================================================
-- ABC_2026_DataSync_Post0813_rollback  (2026-09-04)
-- Reverses ABC_2026_DataSync_Post0813.sql. Data only.
-- Note: RolePermission rows granted to the new permissions after deploy are
-- removed here too, otherwise the Permission delete fails on FK.
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CompanyCode NVARCHAR(40);
SELECT TOP (1) @CompanyCode = CompanyCode FROM dbo.Company;
IF ISNULL(UPPER(LTRIM(RTRIM(@CompanyCode))), '') <> 'ABC'
    THROW 51000, 'This script is only intended for the ABC company database.', 1;

BEGIN TRAN;

-- 1. Permission
IF OBJECT_ID(N'dbo.RolePermission', N'U') IS NOT NULL
    DELETE FROM dbo.RolePermission
    WHERE PermissionId IN (1407,1408,1409,3381,5059,5060,5156,6256,6505,7211,9200,9210,9211,9212);

DELETE FROM dbo.Permission
WHERE PermissionId IN (9212,9211,9210,9200,7211,6505,6256,5156,5060,5059,3381,1409,1408,1407)
  AND PermissionKey IN
  (
    N'Accounting.BankFeed.Rule.List', N'Accounting.BankFeed.Rule.Manage', N'Accounting.BankFeed.Rule.Recalculate',
    N'Customer.Sale.ManagePdfPages', N'Product.Item.ImportCost', N'Product.Item.ApplyCost',
    N'Product.ItemCategory.ImageManage', N'Report.Inventory.POInventoryStatus', N'Report.Item.BasicItem',
    N'Vendor.PurchaseOrder.EmailPdf', N'Intercompany', N'Intercompany.SalesTransfer',
    N'Intercompany.SalesTransfer.View', N'Intercompany.SalesTransfer.Create'
  );

-- Undo the Email PO sort shift (7206..7211 -> 7205..7210).
IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = N'Vendor.PurchaseOrder.EmailPdf')
   AND NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE ParentPermissionId = 7200 AND SortOrder = 7205)
BEGIN
    UPDATE dbo.Permission
    SET SortOrder = SortOrder - 1
    WHERE ParentPermissionId = 7200
      AND SortOrder >= 7206;
END;

-- 2. SchedulerConfig
UPDATE dbo.SchedulerConfig
SET DayOfWeek = 2,
    NextRunTime = NULL,
    UpdatedAt = GETDATE()
WHERE JobName = 'Update Item Prices'
  AND Frequency = 'WEEKLY'
  AND DayOfWeek = 1;

IF NOT EXISTS (SELECT 1 FROM dbo.SchedulerConfig WHERE JobName = 'Update Price Flag')
BEGIN
    SET IDENTITY_INSERT dbo.SchedulerConfig ON;
    INSERT INTO dbo.SchedulerConfig
        (Id, JobName, JobDescription, SpName, Frequency, RunTime, OriginalDayOfWeek, DayOfWeek, DayOfMonth, IsEnabled, CreatedAt)
    VALUES
        (11, 'Update Price Flag', 'Update pricing flags across items', 'Scheduler_UpdatePriceFlag', 'WEEKLY', '23:00:00', NULL, 2, NULL, 0, GETDATE());
    SET IDENTITY_INSERT dbo.SchedulerConfig OFF;
END;

-- 3. SystemSetting
DELETE FROM dbo.SystemSetting
WHERE SettingKey IN (N'INVOICE_PACKED_ITEM_GROUP_ENABLED', N'INTERCOMPANY_ITEM_SYNC_ENABLED', N'INTERCOMPANY_SALES_TRANSFER_ENABLED');

-- 4. Company: nothing to undo.

COMMIT;
GO
