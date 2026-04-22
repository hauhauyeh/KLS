IF COL_LENGTH('dbo.SalesRoute', 'TruckRouteOrder') IS NULL
BEGIN
    ALTER TABLE dbo.SalesRoute
        ADD TruckRouteOrder INT NULL;
END
