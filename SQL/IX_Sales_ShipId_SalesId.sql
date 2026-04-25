SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.Sales')
      AND name = 'IX_Sales_ShipId_SalesId'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Sales_ShipId_SalesId
    ON dbo.Sales (ShipId, SalesId)
    INCLUDE (ShipDate);
END
GO
