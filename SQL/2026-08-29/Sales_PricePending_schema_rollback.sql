SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Rollback for Sales_PricePending_schema.sql (2026-08-29). Idempotent.
-- Deploy only after the SPs of slices 2-4 are rolled back to their live baselines,
-- otherwise Sales_Insert / Sales_PartialUpdate reference dropped columns.

IF OBJECT_ID('dbo.SalesRepriceDetail', 'U') IS NOT NULL DROP TABLE dbo.SalesRepriceDetail;
GO
IF OBJECT_ID('dbo.SalesReprice', 'U') IS NOT NULL DROP TABLE dbo.SalesReprice;
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Sales_IsPricePending' AND object_id = OBJECT_ID('dbo.Sales'))
    DROP INDEX IX_Sales_IsPricePending ON dbo.Sales;
GO

IF COL_LENGTH('dbo.Sales', 'IsPricePending') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Sales DROP CONSTRAINT DF_Sales_IsPricePending;
    ALTER TABLE dbo.Sales DROP COLUMN IsPricePending;
END
GO

IF COL_LENGTH('dbo.SalesDetail', 'IsManualPrice') IS NOT NULL
BEGIN
    ALTER TABLE dbo.SalesDetail DROP CONSTRAINT DF_SalesDetail_IsManualPrice;
    ALTER TABLE dbo.SalesDetail DROP COLUMN IsManualPrice;
END
GO

IF COL_LENGTH('dbo.TempSales', 'IsManualPrice') IS NOT NULL
BEGIN
    ALTER TABLE dbo.TempSales DROP CONSTRAINT DF_TempSales_IsManualPrice;
    ALTER TABLE dbo.TempSales DROP COLUMN IsManualPrice;
END
GO
