-- Deploy: Create Report_SalesDetail SP
-- Migrated from KLS_New with updated column/table names
CREATE PROCEDURE [dbo].[Report_SalesDetail]
    @StartDate DATE,
    @EndDate DATE,
    @ItemCode NVARCHAR(50),
    @SalesRep INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        CAST(ROW_NUMBER() OVER (ORDER BY p.PayeeName, s.ShipDate, i.ItemName) AS INT) AS RowId,
        s.SalesId AS SalesNum,
        s.ShipDate,
        i.ItemCode,
        i.ItemName AS ItemDesc1,
        SUM(sd.ShipQty) AS ShipQty,
        SUM(sd.BillQty) AS BillQty,
        sd.UnitPrice AS Price,
        SUM(sd.ExtTotal) AS ExtTotal,
        SUM(sd.FIFOCost * sd.ShipQty) AS Cost,
        SUM(sd.ExtTotal - (sd.FIFOCost * sd.ShipQty)) AS Margin,
        p.PayeeName AS SalesRepName
    FROM
        Sales AS s
        INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
        INNER JOIN Item AS i ON i.ItemId = sd.ItemId
        LEFT JOIN Payee AS p ON p.PayeeId = s.SalesRepId
    WHERE
        s.ShipDate BETWEEN @StartDate AND @EndDate
        AND (@ItemCode IS NULL OR i.ItemCode = @ItemCode)
        AND (@SalesRep IS NULL OR s.SalesRepId = @SalesRep)
    GROUP BY
        s.SalesId,
        s.ShipDate,
        i.ItemCode,
        i.ItemName,
        p.PayeeName,
        sd.UnitPrice
    ORDER BY
        p.PayeeName,
        s.ShipDate,
        i.ItemName
END
