SET NOCOUNT ON
GO

DECLARE @ConstraintName SYSNAME;

SELECT @ConstraintName = dc.name
FROM sys.default_constraints AS dc
INNER JOIN sys.columns AS c
    ON c.default_object_id = dc.object_id
WHERE dc.parent_object_id = OBJECT_ID('dbo.SalesRouteDetail')
  AND c.name = 'FactorToBase';

IF @ConstraintName IS NOT NULL
    EXEC('ALTER TABLE dbo.SalesRouteDetail DROP CONSTRAINT ' + QUOTENAME(@ConstraintName));
GO

DECLARE @ConstraintName SYSNAME;

SELECT @ConstraintName = dc.name
FROM sys.default_constraints AS dc
INNER JOIN sys.columns AS c
    ON c.default_object_id = dc.object_id
WHERE dc.parent_object_id = OBJECT_ID('dbo.SalesRouteDetail')
  AND c.name = 'BaseQty';

IF @ConstraintName IS NOT NULL
    EXEC('ALTER TABLE dbo.SalesRouteDetail DROP CONSTRAINT ' + QUOTENAME(@ConstraintName));
GO

DECLARE @ConstraintName SYSNAME;

SELECT @ConstraintName = dc.name
FROM sys.default_constraints AS dc
INNER JOIN sys.columns AS c
    ON c.default_object_id = dc.object_id
WHERE dc.parent_object_id = OBJECT_ID('dbo.SalesRouteDetail')
  AND c.name = 'ReturnType';

IF @ConstraintName IS NOT NULL
    EXEC('ALTER TABLE dbo.SalesRouteDetail DROP CONSTRAINT ' + QUOTENAME(@ConstraintName));
GO

DECLARE @ConstraintName SYSNAME;

SELECT @ConstraintName = dc.name
FROM sys.default_constraints AS dc
INNER JOIN sys.columns AS c
    ON c.default_object_id = dc.object_id
WHERE dc.parent_object_id = OBJECT_ID('dbo.SalesRouteDetail')
  AND c.name = 'ResolutionStatus';

IF @ConstraintName IS NOT NULL
    EXEC('ALTER TABLE dbo.SalesRouteDetail DROP CONSTRAINT ' + QUOTENAME(@ConstraintName));
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'CreditMemoSalesId') IS NOT NULL
    ALTER TABLE dbo.SalesRouteDetail DROP COLUMN CreditMemoSalesId;
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'InventoryAdjDetailId') IS NOT NULL
    ALTER TABLE dbo.SalesRouteDetail DROP COLUMN InventoryAdjDetailId;
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'InventoryAdjId') IS NOT NULL
    ALTER TABLE dbo.SalesRouteDetail DROP COLUMN InventoryAdjId;
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'ResolvedBy') IS NOT NULL
    ALTER TABLE dbo.SalesRouteDetail DROP COLUMN ResolvedBy;
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'ResolvedAt') IS NOT NULL
    ALTER TABLE dbo.SalesRouteDetail DROP COLUMN ResolvedAt;
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'ResolutionStatus') IS NOT NULL
    ALTER TABLE dbo.SalesRouteDetail DROP COLUMN ResolutionStatus;
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'ReturnType') IS NOT NULL
    ALTER TABLE dbo.SalesRouteDetail DROP COLUMN ReturnType;
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'BaseQty') IS NOT NULL
    ALTER TABLE dbo.SalesRouteDetail DROP COLUMN BaseQty;
GO

IF COL_LENGTH('dbo.SalesRouteDetail', 'FactorToBase') IS NOT NULL
    ALTER TABLE dbo.SalesRouteDetail DROP COLUMN FactorToBase;
GO
