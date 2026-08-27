-- ============================================================
-- ItemCostImport_v2_schema_rollback  (2026-08-27)
-- Reverses ItemCostImport_v2_schema.sql: recreates the three v1 tables
-- (empty) and the Vendor FK, and makes PayeeId NOT NULL again.
-- NOT NULL only succeeds when no NULL PayeeId rows exist (v2 imports write
-- NULL): delete or backfill those rows first. The three dropped procs are
-- restored by re-running their v1 files from git history if ever needed.
-- Guarded: safe to re-run.
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.VendorItemCode', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.VendorItemCode
    (
        VendorItemCodeId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VendorItemCode PRIMARY KEY,
        PayeeId          INT            NOT NULL CONSTRAINT FK_VendorItemCode_Vendor   REFERENCES dbo.Vendor (PayeeId),
        VendorCode       NVARCHAR(50)   NOT NULL,
        ItemId           INT            NOT NULL CONSTRAINT FK_VendorItemCode_Item     REFERENCES dbo.Item (ItemId),
        ItemUnitId       INT            NOT NULL CONSTRAINT FK_VendorItemCode_ItemUnit REFERENCES dbo.ItemUnit (ItemUnitId),
        LastDescription  NVARCHAR(200)  NULL,
        CreatedAt        DATETIME       NOT NULL CONSTRAINT DF_VendorItemCode_CreatedAt DEFAULT (GETUTCDATE()),
        UpdatedAt        DATETIME       NULL,
        CONSTRAINT UK_VendorItemCode_Payee_Code UNIQUE (PayeeId, VendorCode)
    );
    CREATE INDEX IX_VendorItemCode_Item ON dbo.VendorItemCode (ItemId, ItemUnitId);
END
GO

IF OBJECT_ID('dbo.ItemCostApplyDetail', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ItemCostApplyDetail
    (
        ApplyDetailId  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ItemCostApplyDetail PRIMARY KEY,
        ApplyId        INT           NOT NULL CONSTRAINT FK_ItemCostApplyDetail_Apply REFERENCES dbo.ItemCostApply (ApplyId),
        ItemUnitId     INT           NOT NULL CONSTRAINT FK_ItemCostApplyDetail_ItemUnit REFERENCES dbo.ItemUnit (ItemUnitId),
        OldBaseCost    DECIMAL(18,4) NULL,
        OldLandedCost  DECIMAL(18,4) NULL,
        OldBaseCost2   DECIMAL(18,4) NULL,
        NewBaseCost    DECIMAL(18,4) NULL,
        NewLandedCost  DECIMAL(18,4) NULL,
        NewBaseCost2   DECIMAL(18,4) NULL
    );
    CREATE INDEX IX_ItemCostApplyDetail_Apply ON dbo.ItemCostApplyDetail (ApplyId);
END
GO

IF OBJECT_ID('dbo.ItemCostImportDetail', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ItemCostImportDetail
    (
        ImportDetailId  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ItemCostImportDetail PRIMARY KEY,
        ImportId        INT           NOT NULL CONSTRAINT FK_ItemCostImportDetail_Import REFERENCES dbo.ItemCostImport (ImportId),
        ItemId          INT           NOT NULL,
        ItemUnitId      INT           NOT NULL CONSTRAINT FK_ItemCostImportDetail_ItemUnit REFERENCES dbo.ItemUnit (ItemUnitId),
        OldPendingCost  DECIMAL(18,4) NULL,
        NewPendingCost  DECIMAL(18,4) NOT NULL
    );
    CREATE INDEX IX_ItemCostImportDetail_Import ON dbo.ItemCostImportDetail (ImportId);
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.ItemCostImport') AND name = 'PayeeId' AND is_nullable = 1)
    ALTER TABLE dbo.ItemCostImport ALTER COLUMN PayeeId INT NOT NULL;
GO

IF OBJECT_ID('dbo.FK_ItemCostImport_Vendor', 'F') IS NULL
    ALTER TABLE dbo.ItemCostImport ADD CONSTRAINT FK_ItemCostImport_Vendor FOREIGN KEY (PayeeId) REFERENCES dbo.Vendor (PayeeId);
GO
