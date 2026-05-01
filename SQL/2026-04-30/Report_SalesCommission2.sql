-- Deploy: Create Report_SalesCommission2 SP
-- Migrated from KLS_New with updated column/table names

CREATE OR ALTER PROCEDURE [dbo].[Report_SalesCommission2]
    @StartDate DATE,
    @EndDate DATE,
    @SalesRep INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SalesMargin AS TABLE (
        Id INT IDENTITY(1,1),
        SalesRepId INT,
        SalesRepName NVARCHAR(100),
        SalesNum INT,
        ShipId INT,
        PayeeName NVARCHAR(200),
        ShipDate DATE,
        SalesTotal MONEY,
        CountableTotal MONEY,
        CostTotal MONEY,
        Margin MONEY
    )

    ;WITH Payments AS (
        SELECT cp.CustomerPaymentId, cp.PaymentDate, cp.PaymentAmount
        FROM CustomerPayment cp
        WHERE cp.PaymentDate BETWEEN @StartDate AND @EndDate
    ),
    SalesPayments AS (
        SELECT DISTINCT pd.SalesId
        FROM CustomerPaymentDetail pd
        JOIN Payments AS p ON pd.CustomerPaymentId = p.CustomerPaymentId
        WHERE pd.IsCreditMemo = 0
    ),
    FilteredSales AS (
        SELECT s.SalesId, s.ShipDate, s.ShipId, s.SalesRepId, s.SalesTotal, s.DiscountApplied,
               sd.ShipQty, sd.ExtTotal, sd.FIFOCost
        FROM Sales s
        JOIN SalesPayments sp ON s.SalesId = sp.SalesId
        JOIN SalesDetail sd ON s.SalesId = sd.SalesId
        INNER JOIN Item i ON i.ItemId = sd.ItemId
        WHERE s.AmountDue = 0
          AND i.ItemCode NOT LIKE '%@%'
          AND s.SalesRepId = CASE WHEN @SalesRep IS NOT NULL THEN @SalesRep ELSE s.SalesRepId END
    )

    INSERT INTO @SalesMargin(SalesNum, ShipId, ShipDate, SalesRepId, SalesTotal, CountableTotal, CostTotal)
    SELECT
        s.SalesId,
        s.ShipId,
        s.ShipDate,
        s.SalesRepId,
        s.SalesTotal,
        SUM(s.ExtTotal) - ISNULL(MAX(s.DiscountApplied), 0),
        ISNULL(SUM(s.FIFOCost * s.ShipQty), 0) AS CostTotal
    FROM FilteredSales s
    GROUP BY s.SalesId, s.ShipId, s.ShipDate, s.SalesRepId, s.SalesTotal

    UPDATE @SalesMargin SET Margin = CASE WHEN CountableTotal <> 0 THEN (CountableTotal - CostTotal) / CountableTotal ELSE 0 END

    UPDATE s SET s.SalesRepName = p.PayeeName,
        s.PayeeName = (SELECT PayeeName FROM Payee AS py WHERE py.PayeeId = s.ShipId)
    FROM @SalesMargin AS s LEFT JOIN Payee AS p ON p.PayeeId = s.SalesRepId

    SELECT * FROM @SalesMargin ORDER BY SalesRepName, PayeeName, ShipDate
END
