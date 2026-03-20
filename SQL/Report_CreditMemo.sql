-- Report_CreditMemo — Credit memo listing by date range
CREATE PROCEDURE [dbo].[Report_CreditMemo]
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.SalesId,
        s.SalesNumber,
        p.PayeeName,
        s.ShipDate,
        CAST(SUM(sd.ExtTotal) AS DECIMAL(18,2)) AS SalesTotal,
        s.Instruction,
        eb.PayeeName AS EnteredBy
    FROM dbo.Sales s
    INNER JOIN dbo.SalesDetail sd ON s.SalesId = sd.SalesId
    INNER JOIN dbo.Payee p ON s.ShipId = p.PayeeId
    LEFT JOIN dbo.Payee eb ON s.Enterby = eb.PayeeId
    WHERE s.ShipDate BETWEEN @StartDate AND @EndDate
      AND sd.ItemId NOT IN (SELECT ItemId FROM Item WHERE ItemCode LIKE '@%')
      AND sd.ExtTotal < 0
    GROUP BY s.SalesId, s.SalesNumber, p.PayeeName, s.ShipDate, s.Instruction, eb.PayeeName
    ORDER BY s.ShipDate, p.PayeeName;
END
