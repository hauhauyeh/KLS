-- ============================================================
-- ABC_2026_DataSync_Post0813  (2026-09-04)
--
-- Data-only catch-up for ABC_2026 after the 2026-08-13 upgrade.
-- Reference database: ASAG_2026 (latest). Schema/new tables already applied.
-- Scope: Permission, SchedulerConfig, SystemSetting, Company.
--
-- Built from a live row diff ASAG_2026 vs ABC_2026 (keyed by PermissionKey,
-- JobName, SettingKey, CompanyId), not by replaying the daily scripts.
--
--   Permission      +14 rows missing in ABC (ids free, parents match by id)
--                   +SortOrder shift of Vendor.PurchaseOrder siblings for Email PO
--   SchedulerConfig  'Update Item Prices' DayOfWeek 2 -> 1 (Sun=0..Sat=6 fix, Monday)
--                   'Update Price Flag' row deleted (SP never existed, row retired 08-29)
--   SystemSetting   +3 feature-flag keys (all false)
--                    SALES_ORDER_DOCUMENT_MENU_JSON left as-is (see section 3)
--   Company          no change (all 41 columns exist; values are tenant data)
--
-- Tenant-specific value differences (SYSTEM_START_DATE, DOCUMENT_FORMAT,
-- tax rate, Database Backup enabled, etc.) are intentionally NOT touched.
--
-- Idempotent. Does NOT touch RolePermission; grant through the admin role UI.
-- Rollback: ABC_2026_DataSync_Post0813_rollback.sql
-- Deploy:   sqlcmd -S RAJNI\SQLEXPRESS -d ABC_2026 -C -b -i ABC_2026_DataSync_Post0813.sql
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- ------------------------------------------------------------
-- Guard: ABC company database only
-- ------------------------------------------------------------
DECLARE @CompanyCode NVARCHAR(40);
SELECT TOP (1) @CompanyCode = CompanyCode FROM dbo.Company;
IF ISNULL(UPPER(LTRIM(RTRIM(@CompanyCode))), '') <> 'ABC'
BEGIN
    THROW 51000, 'This script is only intended for the ABC company database.', 1;
END;

BEGIN TRAN;

-- ============================================================
-- 1. Permission
-- ============================================================
DECLARE @Rows TABLE
(
    PermissionId       int            NOT NULL,
    PermissionKey      nvarchar(300)  NOT NULL,
    DisplayName        nvarchar(400)  NOT NULL,
    [Module]           nvarchar(100)  NOT NULL,
    [Resource]         nvarchar(100)  NOT NULL,
    [Action]           nvarchar(100)  NOT NULL,
    PermissionType     nvarchar(40)   NOT NULL,
    ParentPermissionId int            NULL,
    SortOrder          int            NOT NULL,
    OldKey             nvarchar(300)  NULL
);

INSERT INTO @Rows
    (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
VALUES
    -- Bank feed rules (parent 1400 Accounting.BankFeed)
    (1407, N'Accounting.BankFeed.Rule.List',        N'View Bank Feed Rules',                  N'Accounting',   N'BankFeed',      N'Rule.List',        N'page',     1400, 1407, NULL),
    (1408, N'Accounting.BankFeed.Rule.Manage',      N'Manage Bank Feed Rules',                N'Accounting',   N'BankFeed',      N'Rule.Manage',      N'button',   1400, 1408, NULL),
    (1409, N'Accounting.BankFeed.Rule.Recalculate', N'Recalculate Bank Feed Rule Suggestions',N'Accounting',   N'BankFeed',      N'Rule.Recalculate', N'button',   1400, 1409, NULL),
    -- Sales PDF pages (parent 3350 Customer.Sale)
    (3381, N'Customer.Sale.ManagePdfPages',         N'Manage PDF Pages',                      N'Customer',     N'Sale',          N'ManagePdfPages',   N'button',   3350, 3381, N'Sales-ManagePdfPages'),
    -- Item cost import (parent 5050 Product.Item)
    (5059, N'Product.Item.ImportCost',              N'Import Cost',                           N'Product',      N'Item',          N'ImportCost',       N'button',   5050, 5059, NULL),
    (5060, N'Product.Item.ApplyCost',               N'Apply Cost',                            N'Product',      N'Item',          N'ApplyCost',        N'button',   5050, 5060, NULL),
    -- Category images (parent 5150 Product.ItemCategory)
    (5156, N'Product.ItemCategory.ImageManage',     N'Manage Product Category Images',        N'Product',      N'ItemCategory',  N'ImageManage',      N'button',   5150, 5156, NULL),
    -- Reports (parents 6250 Report.Inventory, 6500 Report.Item)
    (6256, N'Report.Inventory.POInventoryStatus',   N'PO Inventory Status',                   N'Report',       N'Inventory',     N'POInventoryStatus',N'page',     6250, 6256, NULL),
    (6505, N'Report.Item.BasicItem',                N'Item -> Basic Item',                    N'Report',       N'Item',          N'BasicItem',        N'page',     6500, 6505, NULL),
    -- Email PO (parent 7200 Vendor.PurchaseOrder). SortOrder 7205 slot; siblings shifted below.
    (7211, N'Vendor.PurchaseOrder.EmailPdf',        N'Email PO',                              N'Vendor',       N'PurchaseOrder', N'EmailPdf',         N'button',   7200, 7205, N'PurchaseOrders-EmailPdf'),
    -- Intercompany (new menu tree)
    (9200, N'Intercompany',                         N'Intercompany',                          N'Intercompany', N'',              N'',                 N'menu',     NULL, 9200, NULL),
    (9210, N'Intercompany.SalesTransfer',           N'Sales Transfer',                        N'Intercompany', N'SalesTransfer', N'',                 N'resource', 9200, 9210, NULL),
    (9211, N'Intercompany.SalesTransfer.View',      N'View Sales Transfer',                   N'Intercompany', N'SalesTransfer', N'View',             N'page',     9210, 9211, NULL),
    (9212, N'Intercompany.SalesTransfer.Create',    N'Create Sales Transfer',                 N'Intercompany', N'SalesTransfer', N'Create',           N'button',   9210, 9212, NULL);

-- Fail fast on id / key collisions.
IF EXISTS (SELECT 1 FROM dbo.Permission p INNER JOIN @Rows r ON r.PermissionId = p.PermissionId WHERE p.PermissionKey <> r.PermissionKey)
    THROW 51001, 'One or more permission ids are already used by different permission keys.', 1;

IF EXISTS (SELECT 1 FROM dbo.Permission p INNER JOIN @Rows r ON r.PermissionKey = p.PermissionKey WHERE p.PermissionId <> r.PermissionId)
    THROW 51002, 'One or more permission keys already exist with different permission ids.', 1;

-- Parents must exist (ids are shared across all KLS databases).
IF EXISTS (SELECT 1 FROM @Rows r WHERE r.ParentPermissionId IS NOT NULL
             AND NOT EXISTS (SELECT 1 FROM dbo.Permission p WHERE p.PermissionId = r.ParentPermissionId)
             AND NOT EXISTS (SELECT 1 FROM @Rows r2 WHERE r2.PermissionId = r.ParentPermissionId))
    THROW 51003, 'One or more parent permission ids are missing.', 1;

-- Email PO takes SortOrder 7205; shift existing Vendor.PurchaseOrder siblings once
-- (CopyToBill 7205->7206 ... Update 7210->7211). Same as Permission_AddPOEmailPdf (2026-08-24).
IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = N'Vendor.PurchaseOrder.EmailPdf')
   AND EXISTS (SELECT 1 FROM dbo.Permission WHERE ParentPermissionId = 7200 AND SortOrder = 7205)
BEGIN
    UPDATE dbo.Permission
    SET SortOrder = SortOrder + 1
    WHERE ParentPermissionId = 7200
      AND SortOrder >= 7205;
END;

SET IDENTITY_INSERT dbo.Permission ON;

INSERT INTO dbo.Permission
    (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
SELECT
    r.PermissionId, r.PermissionKey, r.DisplayName, r.[Module], r.[Resource], r.[Action], r.PermissionType,
    r.ParentPermissionId, r.SortOrder, NULL, r.OldKey, 1, SYSDATETIME()
FROM @Rows r
WHERE NOT EXISTS (SELECT 1 FROM dbo.Permission p WHERE p.PermissionKey = r.PermissionKey)
ORDER BY r.PermissionId;   -- parents (9200, 9210) insert before children

SET IDENTITY_INSERT dbo.Permission OFF;

-- Re-run safety: align attributes of rows that already existed.
UPDATE p
SET DisplayName        = r.DisplayName,
    [Module]           = r.[Module],
    [Resource]         = r.[Resource],
    [Action]           = r.[Action],
    PermissionType     = r.PermissionType,
    ParentPermissionId = r.ParentPermissionId,
    SortOrder          = r.SortOrder,
    OldKey             = r.OldKey,
    IsActive           = 1
FROM dbo.Permission p
INNER JOIN @Rows r ON r.PermissionKey = p.PermissionKey;

-- ============================================================
-- 2. SchedulerConfig
-- ============================================================
-- DayOfWeek is stored .NET style Sun=0..Sat=6 since the 2026-08-29 DOW fix.
-- ABC still holds the old SQL DATEPART value 2 (=Monday under DATEFIRST 7),
-- which the fixed SPs would now read as Tuesday. Reference (ASAG) = 1 (Monday).
UPDATE dbo.SchedulerConfig
SET DayOfWeek = 1,
    OriginalDayOfWeek = NULL,
    NextRunTime = NULL,          -- force recompute from the corrected day
    UpdatedAt = GETDATE()
WHERE JobName = 'Update Item Prices'
  AND Frequency = 'WEEKLY'
  AND DayOfWeek = 2;

-- 'Update Price Flag' -> Scheduler_UpdatePriceFlag never existed; "already updated"
-- is derived from ItemCostApply. Row retired 2026-08-29; reference DB has no row.
DELETE FROM dbo.SchedulerConfig
WHERE JobName = 'Update Price Flag'
  AND SpName = 'Scheduler_UpdatePriceFlag';

-- ============================================================
-- 3. SystemSetting
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = N'INVOICE_PACKED_ITEM_GROUP_ENABLED')
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (N'INVOICE_PACKED_ITEM_GROUP_ENABLED', N'false', N'bool',
            N'When true, invoice detail moves non-cs/non-lbs item lines under the PACKED ITEM group.', SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = N'INTERCOMPANY_ITEM_SYNC_ENABLED')
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (N'INTERCOMPANY_ITEM_SYNC_ENABLED', N'false', N'bool',
            N'Enable intercompany item, category, storage, and image sync tools for this database', SYSUTCDATETIME());

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = N'INTERCOMPANY_SALES_TRANSFER_ENABLED')
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (N'INTERCOMPANY_SALES_TRANSFER_ENABLED', N'false', N'bool',
            N'Enable intercompany sales transfer tools for this database', SYSUTCDATETIME());

-- SALES_ORDER_DOCUMENT_MENU_JSON: intentionally NOT synced.
-- ABC holds an empty string, which the Angular resolver treats as "show the full
-- default menu" (Print Invoice / Pick Ticket / Packing List + all batch actions).
-- The ASAG JSON lists only the Gen/Email actions and no batch section; copying it
-- would hide Print Invoice and every batch print in ABC's Order Manager.

-- ============================================================
-- 4. Company
-- ============================================================
-- No data change. Column set matches ASAG_2026 (41 columns). The new
-- InvoicePayment* / Web* / Support* columns are NULL for ABC by design;
-- fill them from the Company setup screen if ABC wants bank details on invoices.

COMMIT;

-- ============================================================
-- Verification
-- ============================================================
SELECT 'Permission' AS Section, PermissionId, PermissionKey, ParentPermissionId, SortOrder, IsActive
FROM dbo.Permission
WHERE PermissionId IN (1407,1408,1409,3381,5059,5060,5156,6256,6505,7211,9200,9210,9211,9212)
ORDER BY PermissionId;

SELECT 'PO siblings' AS Section, PermissionId, PermissionKey, SortOrder
FROM dbo.Permission
WHERE ParentPermissionId = 7200
ORDER BY SortOrder;

SELECT 'SchedulerConfig' AS Section, Id, JobName, Frequency, DayOfWeek, OriginalDayOfWeek, NextRunTime, IsEnabled
FROM dbo.SchedulerConfig
ORDER BY Id;

SELECT 'SystemSetting' AS Section, Id, SettingKey, LEFT(SettingValue, 60) AS SettingValue, DataType
FROM dbo.SystemSetting
WHERE SettingKey IN (N'INVOICE_PACKED_ITEM_GROUP_ENABLED', N'INTERCOMPANY_ITEM_SYNC_ENABLED',
                     N'INTERCOMPANY_SALES_TRANSFER_ENABLED', N'SALES_ORDER_DOCUMENT_MENU_JSON')
ORDER BY Id;
GO
