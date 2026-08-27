-- ============================================================
-- ItemCostImport_v2_schema  (2026-08-27, plan item-import-cost-v2 "keep 2 tables")
--
-- Trims the v1 schema (ItemCostImport_tables.sql) to what v2 uses:
--   DROP  ItemCostImportDetail, ItemCostApplyDetail   (no per-unit audit / undo)
--   DROP  VendorItemCode                              (no mapping - barcode only)
--   DROP  Item_ImportCostTemplate, Item_ImportCostMissing, VendorItemCode_Save
--   ALTER ItemCostImport.PayeeId -> NULL, FK to Vendor dropped (no vendor concept)
-- Kept: ItemCostImport (upload history), ItemCostApply (once-per-week guard),
--       the three ItemUnit columns.
--
-- Data: on KLS-2026 the three dropped tables hold only undone golden-test
-- rows and 2 test mappings; on MGP-2026 they are empty. Nothing to keep.
-- Rollback: ItemCostImport_v2_schema_rollback.sql (recreates the tables/FK;
-- the three procs come back from their v1 files if ever needed).
-- Guarded: safe to re-run. Deploy AFTER the v2 procs (they no longer
-- reference the dropped tables) - or before; nothing depends on order
-- except that v1 Item_ImportCost / Item_ApplyPendingCost would fail at run
-- time once the detail tables are gone.
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.Item_ImportCostTemplate', 'P') IS NOT NULL DROP PROCEDURE dbo.Item_ImportCostTemplate;
GO
IF OBJECT_ID('dbo.Item_ImportCostMissing', 'P') IS NOT NULL DROP PROCEDURE dbo.Item_ImportCostMissing;
GO
IF OBJECT_ID('dbo.VendorItemCode_Save', 'P') IS NOT NULL DROP PROCEDURE dbo.VendorItemCode_Save;
GO

IF OBJECT_ID('dbo.ItemCostImportDetail', 'U') IS NOT NULL DROP TABLE dbo.ItemCostImportDetail;
GO
IF OBJECT_ID('dbo.ItemCostApplyDetail', 'U') IS NOT NULL DROP TABLE dbo.ItemCostApplyDetail;
GO
IF OBJECT_ID('dbo.VendorItemCode', 'U') IS NOT NULL DROP TABLE dbo.VendorItemCode;
GO

IF OBJECT_ID('dbo.FK_ItemCostImport_Vendor', 'F') IS NOT NULL
    ALTER TABLE dbo.ItemCostImport DROP CONSTRAINT FK_ItemCostImport_Vendor;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.ItemCostImport') AND name = 'PayeeId' AND is_nullable = 0)
    ALTER TABLE dbo.ItemCostImport ALTER COLUMN PayeeId INT NULL;
GO

SELECT
    OBJECT_ID('dbo.ItemCostImportDetail')  AS ImportDetail_ShouldBeNull,
    OBJECT_ID('dbo.ItemCostApplyDetail')   AS ApplyDetail_ShouldBeNull,
    OBJECT_ID('dbo.VendorItemCode')        AS VendorItemCode_ShouldBeNull,
    (SELECT is_nullable FROM sys.columns WHERE object_id = OBJECT_ID('dbo.ItemCostImport') AND name = 'PayeeId') AS PayeeId_IsNullable;
GO
