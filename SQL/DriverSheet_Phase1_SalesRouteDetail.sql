SET NOCOUNT ON
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'FactorToBase') IS NULL
BEGIN
    ALTER TABLE dbo.SalesRouteDetail
    ADD FactorToBase DECIMAL(18,6) NOT NULL
        CONSTRAINT DF_SalesRouteDetail_FactorToBase DEFAULT (1);
END
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'BaseQty') IS NULL
BEGIN
    ALTER TABLE dbo.SalesRouteDetail
    ADD BaseQty DECIMAL(18,6) NOT NULL
        CONSTRAINT DF_SalesRouteDetail_BaseQty DEFAULT (0);
END
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'ReturnType') IS NULL
BEGIN
    ALTER TABLE dbo.SalesRouteDetail
    ADD ReturnType NVARCHAR(30) NOT NULL
        CONSTRAINT DF_SalesRouteDetail_ReturnType DEFAULT ('UNTRACKED');
END
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'ResolutionStatus') IS NULL
BEGIN
    ALTER TABLE dbo.SalesRouteDetail
    ADD ResolutionStatus NVARCHAR(30) NOT NULL
        CONSTRAINT DF_SalesRouteDetail_ResolutionStatus DEFAULT ('PENDING');
END
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'ResolvedAt') IS NULL
BEGIN
    ALTER TABLE dbo.SalesRouteDetail
    ADD ResolvedAt DATETIME NULL;
END
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'ResolvedBy') IS NULL
BEGIN
    ALTER TABLE dbo.SalesRouteDetail
    ADD ResolvedBy INT NULL;
END
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'InventoryAdjId') IS NULL
BEGIN
    ALTER TABLE dbo.SalesRouteDetail
    ADD InventoryAdjId INT NULL;
END
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'InventoryAdjDetailId') IS NULL
BEGIN
    ALTER TABLE dbo.SalesRouteDetail
    ADD InventoryAdjDetailId INT NULL;
END
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'CreditMemoSalesId') IS NULL
BEGIN
    ALTER TABLE dbo.SalesRouteDetail
    ADD CreditMemoSalesId INT NULL;
END
GO

UPDATE srd
SET
    FactorToBase = ISNULL(NULLIF(iu.FactorToBase, 0), 1),
    BaseQty = ROUND(ISNULL(srd.Qty, 0) / ISNULL(NULLIF(iu.FactorToBase, 0), 1), 6),
    ReturnType = ISNULL(NULLIF(srd.ReturnType, ''), 'UNTRACKED'),
    ResolutionStatus = ISNULL(NULLIF(srd.ResolutionStatus, ''), 'PENDING')
FROM dbo.SalesRouteDetail AS srd
LEFT JOIN dbo.ItemUnit AS iu ON iu.ItemUnitId = srd.ItemUnitId;
GO
