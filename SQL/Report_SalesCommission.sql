-- Deploy: Create Report_SalesCommission SP
-- Migrated from KLS_New with updated column/table names

CREATE PROCEDURE [dbo].[Report_SalesCommission]
    @StartDate DATE,
    @EndDate DATE,
    @SalesRep INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH cte AS
    (
        SELECT cp.PaymentApplied AS AmtApplied, c.PayeeId AS CustId, s.SalesRepId,
        (SELECT ISNULL(SUM(BillQty * UnitPrice), 0) FROM SalesDetail sd
         INNER JOIN Item i ON i.ItemId = sd.ItemId
         WHERE sd.SalesId = s.SalesId AND LEFT(i.ItemCode, 1) = '@') AS NonSales
        FROM CustomerPayment AS c
        INNER JOIN CustomerPaymentDetail AS cp ON c.CustomerPaymentId = cp.CustomerPaymentId
        INNER JOIN Sales AS s ON s.SalesId = cp.SalesId
        WHERE cp.IsCreditMemo = 0
          AND c.PaymentDate BETWEEN @StartDate AND @EndDate
          AND s.SalesRepId = CASE WHEN @SalesRep IS NOT NULL THEN @SalesRep ELSE s.SalesRepId END
    )

    SELECT CAST(ROW_NUMBER() OVER(ORDER BY CustId) AS int) AS Rn,
        SalesRepId, CustId,
        ISNULL(SUM(AmtApplied), 0) AS PmtAmt,
        ISNULL(SUM(NonSales), 0) AS NonSales,
        (SELECT PayeeName FROM Payee WHERE PayeeId = SalesRepId) AS SalesRepName,
        (SELECT PayeeName FROM Payee WHERE PayeeId = CustId) AS CustName
    FROM cte
    GROUP BY SalesRepId, CustId
    ORDER BY SalesRepName, CustName
END
