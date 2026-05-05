IF COL_LENGTH('dbo.SalesRoute', 'DriverId') IS NOT NULL
BEGIN
    ALTER TABLE dbo.SalesRoute
        DROP COLUMN DriverId;
END
GO
