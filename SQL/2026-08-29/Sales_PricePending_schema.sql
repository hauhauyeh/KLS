SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================================
-- 2026-08-29  Price-pending orders + reprice audit (plan-reprice-open-orders-v1, slice 1)
--
-- Sales.IsPricePending      : order posted on the price-update day before the weekly
--                             cost apply ran; Sales_RepriceOpenOrders clears it.
-- SalesDetail.IsManualPrice : rep typed/changed the unit price -> reprice must skip it.
-- TempSales.IsManualPrice   : same flag on the cart row, carried into SalesDetail.
--   NOTE: OrgPrice is NOT reused - it is promo-owned (BOGO parks the original price there).
-- SalesReprice / SalesRepriceDetail : audit of every reprice run, per-line old/new price
--                             (also the manual rollback reference for a bad run).
--
-- All ADD COLUMN are NOT NULL WITH DEFAULT 0 -> metadata-only, no table rewrite.
-- Idempotent: safe to re-run. Rollback: Sales_PricePending_schema_rollback.sql
-- ============================================================================

IF COL_LENGTH('dbo.Sales', 'IsPricePending') IS NULL
    ALTER TABLE dbo.Sales
        ADD IsPricePending BIT NOT NULL CONSTRAINT DF_Sales_IsPricePending DEFAULT (0);
GO

IF COL_LENGTH('dbo.SalesDetail', 'IsManualPrice') IS NULL
    ALTER TABLE dbo.SalesDetail
        ADD IsManualPrice BIT NOT NULL CONSTRAINT DF_SalesDetail_IsManualPrice DEFAULT (0);
GO

IF COL_LENGTH('dbo.TempSales', 'IsManualPrice') IS NULL
    ALTER TABLE dbo.TempSales
        ADD IsManualPrice BIT NOT NULL CONSTRAINT DF_TempSales_IsManualPrice DEFAULT (0);
GO

IF OBJECT_ID('dbo.SalesReprice', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SalesReprice (
        RepriceId    INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_SalesReprice PRIMARY KEY,
        ApplyId      INT           NULL,                       -- ItemCostApply.ApplyId when run after a cost apply
        TriggeredBy  NVARCHAR(20)  NOT NULL,                   -- 'SCHEDULER' | 'MANUAL'
        EmpId        INT           NULL,                       -- NULL for scheduler runs
        RunAt        DATETIME2(0)  NOT NULL CONSTRAINT DF_SalesReprice_RunAt DEFAULT (SYSDATETIME()),
        OrderCount   INT           NOT NULL CONSTRAINT DF_SalesReprice_OrderCount DEFAULT (0),   -- orders repriced
        LineCount    INT           NOT NULL CONSTRAINT DF_SalesReprice_LineCount DEFAULT (0),    -- lines changed
        SkippedCount INT           NOT NULL CONSTRAINT DF_SalesReprice_SkippedCount DEFAULT (0), -- Q4: not stage 0 / promo / being edited
        ErrorCount   INT           NOT NULL CONSTRAINT DF_SalesReprice_ErrorCount DEFAULT (0),
        CONSTRAINT FK_SalesReprice_ItemCostApply FOREIGN KEY (ApplyId) REFERENCES dbo.ItemCostApply (ApplyId)
    );
END
GO

IF OBJECT_ID('dbo.SalesRepriceDetail', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SalesRepriceDetail (
        RepriceDetailId INT            IDENTITY(1,1) NOT NULL CONSTRAINT PK_SalesRepriceDetail PRIMARY KEY,
        RepriceId       INT            NOT NULL,
        SalesId         INT            NOT NULL,
        SalesDetailId   INT            NOT NULL,
        OldPrice        DECIMAL(18,4)  NOT NULL,
        NewPrice        DECIMAL(18,4)  NOT NULL,
        CONSTRAINT FK_SalesRepriceDetail_SalesReprice FOREIGN KEY (RepriceId) REFERENCES dbo.SalesReprice (RepriceId)
    );
    CREATE INDEX IX_SalesRepriceDetail_Sales ON dbo.SalesRepriceDetail (SalesId, SalesDetailId);
END
GO

-- Reprice candidates are looked up by flag; keep it cheap on 77k+ rows.
-- NOT a filtered index: a filtered index makes every UPDATE on Sales require QUOTED_IDENTIFIER ON
-- (Msg 1934 from sqlcmd / ops scripts). Plain index on a bit column is cheap enough here.
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Sales_IsPricePending' AND object_id = OBJECT_ID('dbo.Sales') AND has_filter = 1)
    DROP INDEX IX_Sales_IsPricePending ON dbo.Sales;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Sales_IsPricePending' AND object_id = OBJECT_ID('dbo.Sales'))
    CREATE INDEX IX_Sales_IsPricePending ON dbo.Sales (IsPricePending) INCLUDE (StageId, ShipDate);
GO
