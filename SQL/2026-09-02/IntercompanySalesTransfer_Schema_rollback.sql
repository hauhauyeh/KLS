SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF DB_NAME() NOT IN (N'GUS_2026', N'ASAG_2026')
BEGIN
    THROW 51000, 'IntercompanySalesTransfer_Schema_rollback.sql must be run against GUS_2026 or ASAG_2026.', 1;
END
GO

-- WARNING: This rollback deletes all intercompany sales transfer audit rows.

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.IntercompanySalesTransferSource')
      AND name = N'IX_IntercompanySalesTransferSource_TargetShipDate'
)
BEGIN
    DROP INDEX IX_IntercompanySalesTransferSource_TargetShipDate
        ON dbo.IntercompanySalesTransferSource;
END
GO

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.IntercompanySalesTransferSource')
      AND name = N'IX_IntercompanySalesTransferSource_SourceSalesId'
)
BEGIN
    DROP INDEX IX_IntercompanySalesTransferSource_SourceSalesId
        ON dbo.IntercompanySalesTransferSource;
END
GO

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.IntercompanySalesTransferSource')
      AND name = N'IX_IntercompanySalesTransferSource_BatchId'
)
BEGIN
    DROP INDEX IX_IntercompanySalesTransferSource_BatchId
        ON dbo.IntercompanySalesTransferSource;
END
GO

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.IntercompanySalesTransferSource')
      AND name = N'UX_IntercompanySalesTransferSource_TargetSales'
)
BEGIN
    DROP INDEX UX_IntercompanySalesTransferSource_TargetSales
        ON dbo.IntercompanySalesTransferSource;
END
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_IntercompanySalesTransferSource_SourceSales')
BEGIN
    ALTER TABLE dbo.IntercompanySalesTransferSource
        DROP CONSTRAINT FK_IntercompanySalesTransferSource_SourceSales;
END
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_IntercompanySalesTransferSource_Batch')
BEGIN
    ALTER TABLE dbo.IntercompanySalesTransferSource
        DROP CONSTRAINT FK_IntercompanySalesTransferSource_Batch;
END
GO

IF OBJECT_ID(N'dbo.IntercompanySalesTransferSource', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.IntercompanySalesTransferSource;
END
GO

IF OBJECT_ID(N'dbo.IntercompanySalesTransferBatch', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.IntercompanySalesTransferBatch;
END
GO
