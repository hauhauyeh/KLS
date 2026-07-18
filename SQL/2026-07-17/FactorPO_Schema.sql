IF COL_LENGTH('dbo.Purchase', 'FactorPO') IS NULL
BEGIN
    ALTER TABLE dbo.Purchase
        ADD FactorPO NVARCHAR(100) NULL;
END
GO
