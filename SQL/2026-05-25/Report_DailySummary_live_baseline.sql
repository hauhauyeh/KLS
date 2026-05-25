/*
    Report_DailySummary_live_baseline.sql
    Captured 2026-05-25 from dev (COGENT-2024\SQLEXPRESS / KLS_2026).
    Frozen snapshot before the crew-name-via-FK change.
    DO NOT EDIT -- baseline only.
*/
CREATE PROCEDURE [dbo].[Report_DailySummary] --[dbo].[Report_DailySummary] null
    @ShipDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Default date
    IF @ShipDate IS NULL
        SET @ShipDate = CAST(GETDATE() AS DATE);

    SELECT 
        S.SalesNumber,
        S.StageId,
        s.ShipDate,
        S.ShipRoute,
        P.PayeeName,
        S.Instruction,
        S.SalesTotal,
        SR.Driver,
        SR.Loader,
        SR.Checker,
        SR.TruckNumber,
        SR.Officer
    FROM Sales AS S
    INNER JOIN Payee AS P 
        ON S.ShipId = P.PayeeId
    LEFT JOIN SalesRoute AS SR
        ON SR.ShipDate = S.ShipDate
        AND SR.ShipRoute = S.ShipRoute
    WHERE S.ShipDate = @ShipDate
    ORDER BY 
        S.ShipRoute,
        P.PayeeName;
END
