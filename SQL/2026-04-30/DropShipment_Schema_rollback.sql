-- DropShipment_Schema_rollback.sql
-- Reverse drop-ship schema changes

-- 1. Drop indexes
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Purchase_DropShipSalesId' AND object_id = OBJECT_ID('dbo.Purchase'))
    DROP INDEX IX_Purchase_DropShipSalesId ON dbo.Purchase;

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Sales_DropShipPurchaseId' AND object_id = OBJECT_ID('dbo.Sales'))
    DROP INDEX UX_Sales_DropShipPurchaseId ON dbo.Sales;

-- 2. Drop FK constraints
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Purchase_DropShipSales')
    ALTER TABLE dbo.Purchase DROP CONSTRAINT FK_Purchase_DropShipSales;

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Sales_DropShipPurchase')
    ALTER TABLE dbo.Sales DROP CONSTRAINT FK_Sales_DropShipPurchase;

-- 3. Drop columns from Purchase
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Purchase' AND COLUMN_NAME = 'DropShipSalesId')
    ALTER TABLE dbo.Purchase DROP COLUMN DropShipSalesId;

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Purchase' AND COLUMN_NAME = 'IsDropShip')
BEGIN
    ALTER TABLE dbo.Purchase DROP CONSTRAINT IF EXISTS DF__Purchase__IsDropShip;
    ALTER TABLE dbo.Purchase DROP COLUMN IsDropShip;
END

-- 4. Drop columns from Sales
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Sales' AND COLUMN_NAME = 'DropShipPurchaseId')
    ALTER TABLE dbo.Sales DROP COLUMN DropShipPurchaseId;

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Sales' AND COLUMN_NAME = 'IsDropShip')
BEGIN
    ALTER TABLE dbo.Sales DROP CONSTRAINT IF EXISTS DF__Sales__IsDropShip;
    ALTER TABLE dbo.Sales DROP COLUMN IsDropShip;
END

-- 5. Remove @APDS account
DELETE FROM dbo.Account WHERE AccountCode = '@APDS';

PRINT 'DropShipment_Schema rollback applied successfully.';
