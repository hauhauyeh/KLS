CREATE PROCEDURE [dbo].[Report_ARFromInvoice]
    @Term NVARCHAR(50),
    @Sortby NVARCHAR(50),
    @Filterby NVARCHAR(50),
    @SalesRep INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH PaymentCTE AS
    (
        SELECT 
            PayeeId,
            MAX(PaymentDate) AS LastPmtDate,
            SUM(CASE WHEN UnappliedAmount <> 0 THEN UnappliedAmount ELSE 0 END) AS UnAppliedAmt,
            MAX(CASE WHEN rn = 1 THEN PaymentAmount END) AS LastPmtAmt
        FROM
        (
            SELECT *,
                   ROW_NUMBER() OVER(PARTITION BY PayeeId ORDER BY PaymentDate DESC) rn
            FROM CustomerPayment
        ) x
        GROUP BY PayeeId
    ),
    SalesCTE AS
    (
        SELECT 
            ShipId,
            MIN(CASE WHEN AmountDue > 0 THEN ShipDate END) AS OwedSince,
            SUM(CASE WHEN AmountDue <> 0 THEN AmountDue ELSE 0 END) AS TotalAmtDue
        FROM Sales
        GROUP BY ShipId
    ),
    MainCTE AS
    (
        SELECT
            c.Region,
            p.PayeeId,
            p.PayeeName,
            p.PhoneDesc1,
            p.Phone1,
            p.Invoice60,
            p.Invoice90,
            p.InvoiceOver90,
            p.PayeeTotalDue,
            pay.LastPmtDate,
            s.OwedSince,
            pay.LastPmtAmt,
            pay.UnAppliedAmt,
            p.TermId,
            t.DueDays,
            CASE 
                WHEN t.DueDays > 0 AND t.DueDays < 30 
                THEN ISNULL((
                    SELECT SUM(AmountDue)
                    FROM Sales 
                    WHERE ShipId = p.PayeeId 
                      AND InvoiceAging BETWEEN 0 AND t.DueDays
                      AND AmountDue <> 0
                ),0)
                ELSE 0
            END AS Inv0,
            CASE 
                WHEN t.DueDays > 0 AND t.DueDays < 30 
                THEN ISNULL((
                    SELECT SUM(AmountDue)
                    FROM Sales 
                    WHERE ShipId = p.PayeeId 
                      AND InvoiceAging BETWEEN t.DueDays+1 AND 30
                      AND AmountDue <> 0
                ),0)
                ELSE p.Invoice30
            END AS Inv30
        FROM Payee p
        INNER JOIN Customer c ON c.PayeeId = p.PayeeId
        LEFT JOIN Term t ON p.TermId = t.TermId
        LEFT JOIN PaymentCTE pay ON pay.PayeeId = p.PayeeId
        LEFT JOIN SalesCTE s ON s.ShipId = p.PayeeId
        WHERE p.PayeeType = 'c'
          AND (@Term IS NULL OR p.TermId = @Term)
          AND (@SalesRep IS NULL OR c.SalesRepId = @SalesRep)
          AND (
                (@Filterby = '30' AND p.Invoice30 <> 0) OR
                (@Filterby = '60' AND p.Invoice60 <> 0) OR
                (@Filterby = '90' AND p.Invoice90 <> 0) OR
                (@Filterby = '91' AND p.InvoiceOver90 <> 0) OR
                (@Filterby IS NULL AND p.PayeeTotalDue <> 0)
              )
    )

    SELECT *
    FROM MainCTE
    ORDER BY
        CASE WHEN @Sortby = 'Customer' THEN PayeeName END,
        CASE WHEN @Sortby = 'Total' THEN PayeeTotalDue END DESC,
        PayeeName;  -- default fallback

END


