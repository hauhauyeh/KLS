CREATE OR ALTER PROCEDURE [dbo].[Report_SalesDaily2]
    @StartDate DATE,
    @EndDate DATE,
    @SalesRep INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SalesMargin AS TABLE (
        Id INT IDENTITY(1,1),
        SalesNum INT,
        ShipId INT,
        PayeeName NVARCHAR(200),
        ShipDate DATE,
        SalesTotal MONEY,
        CountableTotal MONEY,
        CostTotal MONEY,
        Margin MONEY
    )

    ;WITH FilteredSales AS (
        SELECT s.SalesId, s.ShipDate, s.ShipId, s.SalesTotal, s.DiscountTotal,
               sd.ShipQty, sd.ExtTotal, sd.FIFOCost
        FROM Sales s
        JOIN SalesDetail sd ON s.SalesId = sd.SalesId
        INNER JOIN Item i ON i.ItemId = sd.ItemId
        WHERE s.ShipDate BETWEEN @StartDate AND @EndDate
          AND i.ItemCode NOT LIKE '%@%'
          AND s.SalesRepId = CASE WHEN @SalesRep IS NOT NULL THEN @SalesRep ELSE s.SalesRepId END
    )

    INSERT INTO @SalesMargin(SalesNum, ShipId, ShipDate, SalesTotal, CountableTotal, CostTotal)
    SELECT
        s.SalesId,
        s.ShipId,
        s.ShipDate,
        s.SalesTotal,
        SUM(s.ExtTotal) - ISNULL(s.DiscountTotal, 0),
        ISNULL(SUM(s.FIFOCost * s.ShipQty), 0) AS CostTotal
    FROM FilteredSales s
    GROUP BY s.SalesId, s.ShipId, s.ShipDate, s.SalesTotal, s.DiscountTotal

    UPDATE @SalesMargin SET Margin = (CountableTotal - CostTotal) / CASE WHEN CountableTotal != 0 THEN CountableTotal ELSE 1 END

    UPDATE s SET s.PayeeName = p.PayeeName
    FROM @SalesMargin AS s LEFT JOIN Payee AS p ON p.PayeeId = s.ShipId

    SELECT * FROM @SalesMargin ORDER BY PayeeName, ShipDate, SalesNum
END
