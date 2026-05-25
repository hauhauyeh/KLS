SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Report_JobSummary];
GO

CREATE PROCEDURE [dbo].[Report_JobSummary] -- EXEC Report_JobSummary @StartDate='2026-05-01',@EndDate='2026-05-25'
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    /*
      2026-05-25: crew-name fields now resolved via the FK columns
      (DriverId / LoaderId on SalesRoute), falling back to the cached
      text only when the FK is null (pre-FK-upgrade legacy rows).

      Same rationale as Report_DailySummary's 2026-05-25 update: the
      text columns are denormalized PayeeName caches; FK lookup at
      report query time always returns the current PayeeName.

      GROUP BY mirrors the SELECT expressions exactly (ISNULL coalesce
      on both sides) so SQL Server can match them.
    */

    SELECT
        ROW_NUMBER() OVER (ORDER BY S.ShipDate, S.ShipRoute) AS Rn,
        S.ShipRoute,
        S.ShipDate,
        SUM(S.SalesTotal) AS RouteTotal,
        ISNULL(Pd.PayeeName, R.Driver) AS Driver,
        ISNULL(Pl.PayeeName, R.Loader) AS Loader
    FROM dbo.Sales AS S
    LEFT JOIN dbo.SalesRoute AS R
        ON S.ShipDate = R.ShipDate
        AND S.ShipRoute = R.ShipRoute
    LEFT JOIN dbo.Payee AS Pd
        ON Pd.PayeeId = R.DriverId
    LEFT JOIN dbo.Payee AS Pl
        ON Pl.PayeeId = R.LoaderId
    WHERE S.ShipDate >= @StartDate
      AND S.ShipDate <= @EndDate
    GROUP BY
        S.ShipDate,
        S.ShipRoute,
        ISNULL(Pd.PayeeName, R.Driver),
        ISNULL(Pl.PayeeName, R.Loader)
    ORDER BY
        S.ShipDate,
        S.ShipRoute;
END
GO
