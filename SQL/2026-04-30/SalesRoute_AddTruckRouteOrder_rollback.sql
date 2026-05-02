IF COL_LENGTH('dbo.SalesRoute', 'TruckRouteOrder') IS NOT NULL
BEGIN
    ALTER TABLE dbo.SalesRoute
        DROP COLUMN TruckRouteOrder;
END
