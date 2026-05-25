/*
    Report_JobSummary_live_baseline.sql
    Captured 2026-05-25 from dev.
    Frozen before crew-name-via-FK change.
*/
CREATE PROCEDURE [dbo].[Report_JobSummary]
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        ROW_NUMBER() OVER (ORDER BY S.ShipDate, S.ShipRoute) AS Rn,
        S.ShipRoute,
        S.ShipDate,
        SUM(S.SalesTotal) AS RouteTotal,
        R.Driver,
        R.Loader
    FROM dbo.Sales AS S
    LEFT JOIN dbo.SalesRoute AS R 
        ON S.ShipDate = R.ShipDate 
        AND S.ShipRoute = R.ShipRoute
    WHERE S.ShipDate >= @StartDate
      AND S.ShipDate <= @EndDate
    GROUP BY 
        S.ShipDate,
        S.ShipRoute,
        R.Driver,
        R.Loader
    ORDER BY 
        S.ShipDate,
        S.ShipRoute;
END
