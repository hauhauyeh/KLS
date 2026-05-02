SET QUOTED_IDENTIFIER ON
GO

-- DropShipment_Schema.sql
-- Add drop-ship columns to Sales and Purchase, create @APDS account

-- 1. Sales: add IsDropShip and DropShipPurchaseId
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Sales' AND COLUMN_NAME = 'IsDropShip')
BEGIN
    ALTER TABLE dbo.Sales ADD IsDropShip BIT NOT NULL DEFAULT 0;
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Sales' AND COLUMN_NAME = 'DropShipPurchaseId')
BEGIN
    ALTER TABLE dbo.Sales ADD DropShipPurchaseId INT NULL;
END

-- 2. Purchase: add IsDropShip and DropShipSalesId
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Purchase' AND COLUMN_NAME = 'IsDropShip')
BEGIN
    ALTER TABLE dbo.Purchase ADD IsDropShip BIT NOT NULL DEFAULT 0;
END

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Purchase' AND COLUMN_NAME = 'DropShipSalesId')
BEGIN
    ALTER TABLE dbo.Purchase ADD DropShipSalesId INT NULL;
END
GO

-- 3. FK constraints (NO ACTION deletes)
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Sales_DropShipPurchase')
BEGIN
    ALTER TABLE dbo.Sales
        ADD CONSTRAINT FK_Sales_DropShipPurchase
        FOREIGN KEY (DropShipPurchaseId) REFERENCES dbo.Purchase(PurchaseId)
        ON DELETE NO ACTION;
END

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Purchase_DropShipSales')
BEGIN
    ALTER TABLE dbo.Purchase
        ADD CONSTRAINT FK_Purchase_DropShipSales
        FOREIGN KEY (DropShipSalesId) REFERENCES dbo.Sales(SalesId)
        ON DELETE NO ACTION;
END
GO

-- 4. Unique filtered index on Sales.DropShipPurchaseId (one purchase per sales)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Sales_DropShipPurchaseId' AND object_id = OBJECT_ID('dbo.Sales'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_Sales_DropShipPurchaseId
        ON dbo.Sales(DropShipPurchaseId)
        WHERE DropShipPurchaseId IS NOT NULL;
END
GO

-- 5. Nonclustered index on Purchase.DropShipSalesId
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Purchase_DropShipSalesId' AND object_id = OBJECT_ID('dbo.Purchase'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Purchase_DropShipSalesId
        ON dbo.Purchase(DropShipSalesId)
        WHERE DropShipSalesId IS NOT NULL;
END
GO

-- 6. Insert @APDS account (AP - Drop Shipment Accrual) under Accounts Payable category
IF NOT EXISTS (SELECT 1 FROM dbo.Account WHERE AccountCode = '@APDS')
BEGIN
    INSERT INTO dbo.Account
        (AccountCategoryId, TypeName, SortOrder, IsAccountDebit, AccountCode, AccountName, AccountNumber, Description, AccountBalance, Inactive, IsDefaultAccount, CreatedAt)
    VALUES
        (79, NULL, 31, 0, '@APDS', 'AP - Drop Shipment Accrual', NULL, 'Clearing account for drop shipment accrual', 0, 0, 0, GETUTCDATE());
END

PRINT 'DropShipment_Schema applied successfully.';
