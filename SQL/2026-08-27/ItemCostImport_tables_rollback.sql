-- ============================================================
-- ItemCostImport_tables_rollback  (2026-08-27)
-- Reverses ItemCostImport_tables.sql. Order matters: children first,
-- then the FK target ItemCostApply, then the ItemUnit columns.
-- DATA LOSS: drops all import / apply history and any pending costs.
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.ItemCostImportDetail', 'U') IS NOT NULL DROP TABLE dbo.ItemCostImportDetail;
GO
IF OBJECT_ID('dbo.ItemCostImport', 'U') IS NOT NULL DROP TABLE dbo.ItemCostImport;
GO
IF OBJECT_ID('dbo.ItemCostApplyDetail', 'U') IS NOT NULL DROP TABLE dbo.ItemCostApplyDetail;
GO
IF OBJECT_ID('dbo.ItemCostApply', 'U') IS NOT NULL DROP TABLE dbo.ItemCostApply;
GO
IF OBJECT_ID('dbo.VendorItemCode', 'U') IS NOT NULL DROP TABLE dbo.VendorItemCode;
GO

IF COL_LENGTH('dbo.ItemUnit', 'PendingBaseCost2') IS NOT NULL
    ALTER TABLE dbo.ItemUnit DROP COLUMN PendingBaseCost2;
GO
IF COL_LENGTH('dbo.ItemUnit', 'PendingBaseCost') IS NOT NULL
    ALTER TABLE dbo.ItemUnit DROP COLUMN PendingBaseCost;
GO
IF COL_LENGTH('dbo.ItemUnit', 'RecentBaseCost2') IS NOT NULL
    ALTER TABLE dbo.ItemUnit DROP COLUMN RecentBaseCost2;
GO
