-- ============================================================
-- Phase 1: Cart Architecture — Parent/Child Line Grouping
-- Adds structural columns to TempSales and SalesDetail
-- ============================================================

-- TempSales: add 5 structural columns
ALTER TABLE TempSales ADD
    ParentTempSalesId INT NULL,
    RootTempSalesId   INT NULL,
    CartLineType      NVARCHAR(30) NOT NULL DEFAULT 'MAIN',
    IsSystemManaged   BIT NOT NULL DEFAULT 0,
    DisplaySort       INT NULL;

-- SalesDetail: add 5 matching columns
ALTER TABLE SalesDetail ADD
    ParentSalesDetailId INT NULL,
    RootSalesDetailId   INT NULL,
    CartLineType        NVARCHAR(30) NOT NULL DEFAULT 'MAIN',
    IsSystemManaged     BIT NOT NULL DEFAULT 0,
    DisplaySort         INT NULL;
