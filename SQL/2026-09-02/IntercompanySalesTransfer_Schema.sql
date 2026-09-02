SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF DB_NAME() NOT IN (N'GUS_2026', N'ASAG_2026')
BEGIN
    THROW 51000, 'IntercompanySalesTransfer_Schema.sql must be run against GUS_2026 or ASAG_2026.', 1;
END
GO

IF OBJECT_ID(N'dbo.IntercompanySalesTransferBatch', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.IntercompanySalesTransferBatch
    (
        BatchId int IDENTITY(1,1) NOT NULL,
        TargetCode nvarchar(20) NOT NULL,
        TargetDatabaseName nvarchar(128) NOT NULL,
        FromShipDate date NOT NULL,
        ToShipDate date NOT NULL,
        Status nvarchar(20) NOT NULL
            CONSTRAINT DF_IntercompanySalesTransferBatch_Status DEFAULT (N'Previewed'),
        SourceSalesCount int NOT NULL
            CONSTRAINT DF_IntercompanySalesTransferBatch_SourceSalesCount DEFAULT ((0)),
        TargetSalesCount int NOT NULL
            CONSTRAINT DF_IntercompanySalesTransferBatch_TargetSalesCount DEFAULT ((0)),
        LineCount int NOT NULL
            CONSTRAINT DF_IntercompanySalesTransferBatch_LineCount DEFAULT ((0)),
        TotalQty decimal(18,6) NOT NULL
            CONSTRAINT DF_IntercompanySalesTransferBatch_TotalQty DEFAULT ((0)),
        TotalAmount decimal(18,2) NOT NULL
            CONSTRAINT DF_IntercompanySalesTransferBatch_TotalAmount DEFAULT ((0)),
        CreatedBy int NOT NULL,
        CreatedAt datetime NOT NULL
            CONSTRAINT DF_IntercompanySalesTransferBatch_CreatedAt DEFAULT (GETUTCDATE()),
        CompletedAt datetime NULL,
        ErrorMessage nvarchar(1000) NULL,
        CONSTRAINT PK_IntercompanySalesTransferBatch
            PRIMARY KEY CLUSTERED (BatchId),
        CONSTRAINT CK_IntercompanySalesTransferBatch_DateRange
            CHECK (FromShipDate <= ToShipDate),
        CONSTRAINT CK_IntercompanySalesTransferBatch_Status
            CHECK (Status IN (N'Previewed', N'Completed', N'Failed'))
    );
END
GO

IF OBJECT_ID(N'dbo.IntercompanySalesTransferSource', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.IntercompanySalesTransferSource
    (
        TransferSourceId int IDENTITY(1,1) NOT NULL,
        BatchId int NOT NULL,
        TargetCode nvarchar(20) NOT NULL,
        TargetDatabaseName nvarchar(128) NOT NULL,
        TargetSalesId int NOT NULL,
        TargetSalesNumber int NULL,
        TargetSalesDocNumber nvarchar(50) NULL,
        TargetShipDate date NOT NULL,
        TargetStageId int NOT NULL,
        SourceSalesId int NOT NULL,
        SourceSalesNumber int NULL,
        TargetSalesTotal decimal(18,2) NULL,
        CreatedAt datetime NOT NULL
            CONSTRAINT DF_IntercompanySalesTransferSource_CreatedAt DEFAULT (GETUTCDATE()),
        CONSTRAINT PK_IntercompanySalesTransferSource
            PRIMARY KEY CLUSTERED (TransferSourceId)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_IntercompanySalesTransferSource_Batch')
BEGIN
    ALTER TABLE dbo.IntercompanySalesTransferSource WITH CHECK
        ADD CONSTRAINT FK_IntercompanySalesTransferSource_Batch
            FOREIGN KEY (BatchId)
            REFERENCES dbo.IntercompanySalesTransferBatch (BatchId);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_IntercompanySalesTransferSource_SourceSales')
BEGIN
    ALTER TABLE dbo.IntercompanySalesTransferSource WITH CHECK
        ADD CONSTRAINT FK_IntercompanySalesTransferSource_SourceSales
            FOREIGN KEY (SourceSalesId)
            REFERENCES dbo.Sales (SalesId);
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.IntercompanySalesTransferSource')
      AND name = N'UX_IntercompanySalesTransferSource_TargetSales'
)
BEGIN
    CREATE UNIQUE INDEX UX_IntercompanySalesTransferSource_TargetSales
        ON dbo.IntercompanySalesTransferSource (TargetCode, TargetDatabaseName, TargetSalesId);
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.IntercompanySalesTransferSource')
      AND name = N'IX_IntercompanySalesTransferSource_BatchId'
)
BEGIN
    CREATE INDEX IX_IntercompanySalesTransferSource_BatchId
        ON dbo.IntercompanySalesTransferSource (BatchId);
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.IntercompanySalesTransferSource')
      AND name = N'IX_IntercompanySalesTransferSource_SourceSalesId'
)
BEGIN
    CREATE INDEX IX_IntercompanySalesTransferSource_SourceSalesId
        ON dbo.IntercompanySalesTransferSource (SourceSalesId);
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.IntercompanySalesTransferSource')
      AND name = N'IX_IntercompanySalesTransferSource_TargetShipDate'
)
BEGIN
    CREATE INDEX IX_IntercompanySalesTransferSource_TargetShipDate
        ON dbo.IntercompanySalesTransferSource (TargetCode, TargetDatabaseName, TargetShipDate);
END
GO
