-- Deploy: Create Report_ServiceSummary SP
-- Legacy-compatible sales summary grouped by service rep entered-by
-- Current schema replacement for legacy Payee.EmpIsService: Employee.IsService

CREATE OR ALTER PROCEDURE [dbo].[Report_ServiceSummary]
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.PayeeId,
        p.PayeeName,
        CAST(SUM(s.SalesTotal) AS DECIMAL(18,2)) AS Total
    FROM dbo.Sales AS s
    LEFT JOIN dbo.Payee AS p ON s.Enterby = p.PayeeId
    INNER JOIN dbo.Employee AS e ON e.PayeeId = p.PayeeId
    WHERE s.ShipDate BETWEEN @StartDate AND @EndDate
      AND e.IsService = 1
    GROUP BY p.PayeeId, p.PayeeName
    ORDER BY p.PayeeName;
END
