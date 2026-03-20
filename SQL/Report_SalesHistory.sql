-- Report_SalesHistory — Sales history for a customer with optional date range
CREATE PROCEDURE [dbo].[Report_SalesHistory]
    @PayeeId INT,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.SalesId,
        s.SalesNumber,
        s.ShipDate,
        s.ShipRoute,
        CAST(s.SalesTotal AS DECIMAL(18,2)) AS SalesTotal
    FROM dbo.Sales s
    WHERE s.ShipId = @PayeeId
      AND (@StartDate IS NULL OR s.ShipDate >= @StartDate)
      AND (@EndDate IS NULL OR s.ShipDate <= @EndDate)
    ORDER BY s.ShipDate DESC, s.SalesNumber DESC;
END
