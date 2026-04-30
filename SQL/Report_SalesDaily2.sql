-- Deploy: Create Report_SalesDaily2 SP
-- Migrated from KLS_New with updated column/table names

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
        SELECT
            s.SalesId,
            s.SalesNumber,
            s.ShipDate,
            s.ShipId,
            s.SalesTotal,
            s.DiscountApplied,
            COALESCE(s.SalesMarginOrderPercent, s.SalesMarginPercent, 0) AS MarginPercent,
            sd.ExtTotal
        FROM Sales s
        JOIN SalesDetail sd ON s.SalesId = sd.SalesId
        INNER JOIN Item i ON i.ItemId = sd.ItemId
        WHERE s.ShipDate BETWEEN @StartDate AND @EndDate
          AND i.ItemCode NOT LIKE '%@%'
          AND s.SalesRepId = CASE WHEN @SalesRep IS NOT NULL THEN @SalesRep ELSE s.SalesRepId END
    )

    INSERT INTO @SalesMargin(SalesNum, ShipId, ShipDate, SalesTotal, CountableTotal, CostTotal)
    SELECT
        s.SalesNumber,
        s.ShipId,
        s.ShipDate,
        MAX(s.SalesTotal),
        SUM(s.ExtTotal) - ISNULL(MAX(s.DiscountApplied), 0),
        (SUM(s.ExtTotal) - ISNULL(MAX(s.DiscountApplied), 0))
            * (1 - COALESCE(MAX(s.MarginPercent), 0)) AS CostTotal
    FROM FilteredSales s
    GROUP BY s.SalesNumber, s.ShipId, s.ShipDate

    UPDATE @SalesMargin SET Margin = (CountableTotal - CostTotal) / CASE WHEN CountableTotal != 0 THEN CountableTotal ELSE 1 END

    UPDATE s SET s.PayeeName = p.PayeeName
    FROM @SalesMargin AS s LEFT JOIN Payee AS p ON p.PayeeId = s.ShipId

    SELECT * FROM @SalesMargin ORDER BY PayeeName, ShipDate, SalesNum
END
