SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Report_DailySummary];
GO

CREATE PROCEDURE [dbo].[Report_DailySummary] -- EXEC Report_DailySummary @ShipDate=NULL
-- EXEC Report_DailySummary @ShipDate='2026-05-22'
    @ShipDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Default date
    IF @ShipDate IS NULL
        SET @ShipDate = CAST(GETDATE() AS DATE);

    /*
      2026-05-25: crew-name fields now resolved via the FK columns first
      (DriverId / LoaderId / CheckerId / OfficerId added 2026-05-04 + 2026-05-25),
      with ISNULL fallback to the SalesRoute text columns for legacy rows
      where the FK is not yet populated.

      Why: the text columns are denormalized PayeeName caches updated at
      SalesRoute save time. If an employee's PayeeName changes after that
      save, the cached text gets stale. Resolving via the FK at report
      query time shows the current name.

      Fallback rule: when FK is NULL (pre-upgrade row), the cached text
      is the only thing we have, so use it as-is.
    */

    SELECT
        S.SalesNumber,
        S.StageId,
        s.ShipDate,
        S.ShipRoute,
        P.PayeeName,
        S.Instruction,
        S.SalesTotal,
        ISNULL(Pd.PayeeName, SR.Driver)  AS Driver,
        ISNULL(Pl.PayeeName, SR.Loader)  AS Loader,
        ISNULL(Pc.PayeeName, SR.Checker) AS Checker,
        SR.TruckNumber,
        ISNULL(Po.PayeeName, SR.Officer) AS Officer
    FROM Sales AS S
    INNER JOIN Payee AS P
        ON S.ShipId = P.PayeeId
    LEFT JOIN SalesRoute AS SR
        ON SR.ShipDate = S.ShipDate
        AND SR.ShipRoute = S.ShipRoute
    LEFT JOIN Payee AS Pd
        ON Pd.PayeeId = SR.DriverId
    LEFT JOIN Payee AS Pl
        ON Pl.PayeeId = SR.LoaderId
    LEFT JOIN Payee AS Pc
        ON Pc.PayeeId = SR.CheckerId
    LEFT JOIN Payee AS Po
        ON Po.PayeeId = SR.OfficerId
    WHERE S.ShipDate = @ShipDate
    ORDER BY
        S.ShipRoute,
        P.PayeeName;
END
GO
