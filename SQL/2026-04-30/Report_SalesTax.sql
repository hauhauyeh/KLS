-- Deploy: Create Report_SalesTax SP
-- Legacy-aligned calculation basis: BillQty * Price
-- In current schema, Price is represented by SalesDetail.UnitPrice.
-- Legacy @-account rows map to current SalesDetail.LineType = 'A'.

CREATE OR ALTER PROCEDURE [dbo].[Report_SalesTax]
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH cte AS
    (
        SELECT
            p.PayeeName,
            p.PayeeId,
            CASE
                WHEN sd.IsTaxable = 1 THEN ISNULL(SUM(sd.BillQty * sd.UnitPrice), 0)
                ELSE 0
            END AS TaxableSales,
            CASE
                WHEN sd.IsTaxable = 0 AND ISNULL(sd.LineType, 'I') <> 'A' THEN ISNULL(SUM(sd.BillQty * sd.UnitPrice), 0)
                ELSE 0
            END AS NonTaxableSales,
            CASE
                WHEN sd.IsTaxable = 0 AND sd.LineType = 'A' THEN ISNULL(SUM(sd.BillQty * sd.UnitPrice), 0)
                ELSE 0
            END AS NonSales
        FROM dbo.Sales AS s
        INNER JOIN dbo.SalesDetail AS sd ON s.SalesId = sd.SalesId
        INNER JOIN dbo.Payee AS p ON p.PayeeId = s.ShipId
        WHERE s.ShipDate >= ISNULL(@StartDate, s.ShipDate)
          AND s.ShipDate <= ISNULL(@EndDate, s.ShipDate)
        GROUP BY p.PayeeName, p.PayeeId, sd.IsTaxable, sd.LineType
    )
    SELECT
        PayeeName,
        SUM(TaxableSales) AS TaxableSales,
        SUM(NonTaxableSales) AS NonTaxableSales,
        SUM(NonSales) AS NonSales,
        (
            SELECT ISNULL(SUM(TaxTotal), 0)
            FROM dbo.Sales
            WHERE ShipId = cte.PayeeId
              AND ShipDate >= ISNULL(@StartDate, ShipDate)
              AND ShipDate <= ISNULL(@EndDate, ShipDate)
        ) AS TaxTotal
    FROM cte
    GROUP BY PayeeId, PayeeName
    ORDER BY PayeeName;
END
