-- ============================================================
-- ItemCostImport_tables  (2026-08-27, plan item-import-cost-v1 Slice 1)
--
-- Schema for the Import Cost feature:
--   ItemUnit        + RecentBaseCost2, PendingBaseCost, PendingBaseCost2
--   VendorItemCode    vendor product code -> our item + unit (permanent mapping)
--   ItemCostImport    one uploaded file (header) + ItemCostImportDetail (staged per unit)
--   ItemCostApply     one "apply pending" run (header) + ItemCostApplyDetail (live old/new per unit)
--
-- Rollback: ItemCostImport_tables_rollback.sql
-- Guarded: safe to re-run.
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ------------------------------------------------------------
-- ItemUnit columns
--   RecentBaseCost2  live tier-2 vendor cost per unit (display / compare only)
--   PendingBaseCost  staged tier-1 cost per unit, moved to RecentBaseCost/RecentCost by Item_ApplyPendingCost
--   PendingBaseCost2 staged tier-2 cost per unit, moved to RecentBaseCost2 by Item_ApplyPendingCost
-- Same precision and per-unit scaling as RecentBaseCost. Not touched by ItemUnit_UpdateRecentCost.
-- ------------------------------------------------------------
IF COL_LENGTH('dbo.ItemUnit', 'RecentBaseCost2') IS NULL
    ALTER TABLE dbo.ItemUnit ADD RecentBaseCost2 DECIMAL(18,4) NULL;
GO
IF COL_LENGTH('dbo.ItemUnit', 'PendingBaseCost') IS NULL
    ALTER TABLE dbo.ItemUnit ADD PendingBaseCost DECIMAL(18,4) NULL;
GO
IF COL_LENGTH('dbo.ItemUnit', 'PendingBaseCost2') IS NULL
    ALTER TABLE dbo.ItemUnit ADD PendingBaseCost2 DECIMAL(18,4) NULL;
GO

-- ------------------------------------------------------------
-- VendorItemCode: what the vendor calls the product -> our item + unit.
-- One vendor code maps to exactly one unit; UNIQUE (PayeeId, VendorCode)
-- makes the old MGP "same BarcodeW on 3 items" situation impossible.
-- LastDescription is refreshed on every import so the template and the
-- "not in file" list stay readable.
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- ItemCostApply: one apply run (manual button or scheduler).
-- ScheduleDate = the schedule day this run belongs to (local server date);
-- the once-per-week guard in Item_ApplyPendingCost reads it.
-- Created before ItemCostImport because ItemCostImport.ApplyId references it.
-- ------------------------------------------------------------
IF OBJECT_ID('dbo.ItemCostApply', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ItemCostApply
    (
        ApplyId      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ItemCostApply PRIMARY KEY,
        AppliedAt    DATETIME     NOT NULL CONSTRAINT DF_ItemCostApply_AppliedAt DEFAULT (GETUTCDATE()),
        TriggeredBy  NVARCHAR(20) NOT NULL CONSTRAINT CK_ItemCostApply_TriggeredBy CHECK (TriggeredBy IN ('MANUAL', 'SCHEDULER')),
        EmpId        INT          NULL,
        ScheduleDate DATE         NOT NULL,
        UnitCount1   INT          NOT NULL CONSTRAINT DF_ItemCostApply_UnitCount1 DEFAULT (0),
        UnitCount2   INT          NOT NULL CONSTRAINT DF_ItemCostApply_UnitCount2 DEFAULT (0),
        UndoneAt     DATETIME     NULL
    );

    CREATE INDEX IX_ItemCostApply_ScheduleDate ON dbo.ItemCostApply (ScheduleDate) INCLUDE (UndoneAt);
END
GO

-- ------------------------------------------------------------
-- ItemCostApplyDetail: live values before/after per unit. NULLs preserved.
-- This is the rollback source for live prices (ItemCostApply_Undo.sql).
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- ItemCostImport: one uploaded file. ApplyId is stamped by the apply that
-- consumed it; NULL = still pending. Tier 1 = pricing cost, Tier 2 = reference.
-- ------------------------------------------------------------
IF OBJECT_ID('dbo.ItemCostImport', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ItemCostImport
    (
        ImportId      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ItemCostImport PRIMARY KEY,
        PayeeId       INT           NOT NULL CONSTRAINT FK_ItemCostImport_Vendor REFERENCES dbo.Vendor (PayeeId),
        Tier          TINYINT       NOT NULL CONSTRAINT CK_ItemCostImport_Tier CHECK (Tier IN (1, 2)),
        FileName      NVARCHAR(255) NULL,
        EffectiveFrom DATE          NULL,
        EffectiveTo   DATE          NULL,
        EmpId         INT           NULL,
        FileRowCount      INT           NOT NULL CONSTRAINT DF_ItemCostImport_RowCount DEFAULT (0),
        UpdatedCount  INT           NOT NULL CONSTRAINT DF_ItemCostImport_UpdatedCount DEFAULT (0),
        UnmappedCount INT           NOT NULL CONSTRAINT DF_ItemCostImport_UnmappedCount DEFAULT (0),
        MarketCount   INT           NOT NULL CONSTRAINT DF_ItemCostImport_MarketCount DEFAULT (0),
        CreatedAt     DATETIME      NOT NULL CONSTRAINT DF_ItemCostImport_CreatedAt DEFAULT (GETUTCDATE()),
        ApplyId       INT           NULL CONSTRAINT FK_ItemCostImport_Apply REFERENCES dbo.ItemCostApply (ApplyId),
        UndoneAt      DATETIME      NULL
    );

    CREATE INDEX IX_ItemCostImport_Pending ON dbo.ItemCostImport (ApplyId, UndoneAt) INCLUDE (PayeeId, Tier, CreatedAt);
END
GO

-- ------------------------------------------------------------
-- ItemCostImportDetail: what the import staged per unit, and the pending
-- value it replaced (NULL unless a re-import). Rollback source for
-- ItemCostImport_Undo.sql (not-yet-applied imports only).
-- ------------------------------------------------------------
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
