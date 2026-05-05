IF COL_LENGTH('dbo.SalesRoute', 'DriverId') IS NULL
BEGIN
    ALTER TABLE dbo.SalesRoute
        ADD DriverId INT NULL;
END
GO
