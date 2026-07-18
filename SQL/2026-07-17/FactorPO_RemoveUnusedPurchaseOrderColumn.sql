IF COL_LENGTH('dbo.PurchaseOrder', 'FactorPO') IS NOT NULL
BEGIN
    ALTER TABLE dbo.PurchaseOrder
        DROP COLUMN FactorPO;
END
GO
