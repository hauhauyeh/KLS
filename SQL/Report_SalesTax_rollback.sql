CREATE OR ALTER PROCEDURE [dbo].[Report_SalesTax]
    @StartDate date = NULL,
    @EndDate   date = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH SalesFiltered AS
    (
        SELECT
            s.SalesId,
            s.SalesNumber,
            s.ShipId,
            s.TaxTotal
        FROM dbo.Sales s
        WHERE
            (@StartDate IS NULL OR s.ShipDate >= @StartDate)
            AND (@EndDate IS NULL OR s.ShipDate <= @EndDate)
    ),
    DetailAgg AS
    (
        SELECT
            sf.ShipId,
            TaxableSales =
                SUM(CASE WHEN sd.IsTaxable = 1
                         THEN sd.BaseBillQty * sd.UnitPrice
                         ELSE 0 END),
            NonTaxableSales =
                SUM(CASE WHEN sd.IsTaxable = 0 AND sd.LineType = 'I'
                         THEN sd.BaseBillQty * sd.UnitPrice
                         ELSE 0 END),
            NonSales =
                SUM(CASE WHEN sd.IsTaxable = 0 AND sd.LineType = 'A'
                         THEN sd.BaseBillQty * sd.UnitPrice
                         ELSE 0 END)
        FROM SalesFiltered sf
        INNER JOIN dbo.SalesDetail sd ON sd.SalesId = sf.SalesId
        GROUP BY sf.ShipId
    ),
    TaxAgg AS
    (
        SELECT
            sf.ShipId,
            TaxTotal = ISNULL(SUM(sf.TaxTotal), 0)
        FROM SalesFiltered sf
        GROUP BY sf.ShipId
    )
    SELECT
        p.PayeeName,
        TaxableSales     = ISNULL(d.TaxableSales, 0),
        NonTaxableSales  = ISNULL(d.NonTaxableSales, 0),
        NonSales         = ISNULL(d.NonSales, 0),
        TaxTotal         = ISNULL(t.TaxTotal, 0)
    FROM dbo.Payee p
    LEFT JOIN DetailAgg d ON d.ShipId = p.PayeeId
    LEFT JOIN TaxAgg    t ON t.ShipId = p.PayeeId
    WHERE
        (d.ShipId IS NOT NULL OR t.ShipId IS NOT NULL)
    ORDER BY
        p.PayeeName;
END
