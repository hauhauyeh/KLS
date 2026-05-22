CREATE PROCEDURE [dbo].[Report_APFromInvoice] --[dbo].[Report_APFromInvoice] null,null,null
(
    @Term NVARCHAR(50),
    @Sortby NVARCHAR(50),
    @Filterby NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH PurchaseAgg AS
    (
        SELECT 
            PayeeId,
            SUM(CASE WHEN InvoiceAging >= 0 AND InvoiceAging <= 30 AND AmountDue <> 0 THEN AmountDue ELSE 0 END) AS Inv0To30,
            SUM(CASE WHEN InvoiceAging BETWEEN 31 AND 60 AND AmountDue <> 0 THEN AmountDue ELSE 0 END) AS Inv31To60,
            SUM(CASE WHEN InvoiceAging BETWEEN 61 AND 90 AND AmountDue <> 0 THEN AmountDue ELSE 0 END) AS Inv61To90,
            SUM(CASE WHEN InvoiceAging > 90 AND AmountDue <> 0 THEN AmountDue ELSE 0 END) AS InvOver90
        FROM Purchase
        GROUP BY PayeeId
    )

    SELECT 
        p.PayeeId,
        p.PayeeName,
        p.PhoneDesc1,
        p.Phone1,
        p.Invoice60,
        p.Invoice90,
        p.InvoiceOver90,
        p.PayeeTotalDue,
        p.TermId,
        NULL AS Region,
        t.DueDays,

        -- Optimized Aging Logic
        CASE 
            WHEN t.DueDays > 0 AND t.DueDays < 30 
                THEN ISNULL(pa.Inv0To30,0)
            ELSE 0
        END AS Inv0,

        CASE 
            WHEN t.DueDays > 0 AND t.DueDays < 30 
                THEN ISNULL(pa.Inv31To60,0)
            ELSE p.Invoice30
        END AS Inv30

    FROM Payee p 
    INNER JOIN Vendor v ON v.PayeeId = p.PayeeId
    LEFT JOIN Term t ON p.TermId = t.TermId
    LEFT JOIN PurchaseAgg pa ON pa.PayeeId = p.PayeeId

    WHERE p.PayeeType = 'V'
        AND (@Term IS NULL OR p.TermId = @Term)
        AND (
                (@Filterby = '30' AND p.Invoice30 <> 0) OR
                (@Filterby = '60' AND p.Invoice60 <> 0) OR
                (@Filterby = '90' AND p.Invoice90 <> 0) OR
                (@Filterby = '91' AND p.InvoiceOver90 <> 0) OR
                (@Filterby IS NULL AND p.PayeeTotalDue <> 0)
            )

    ORDER BY
        CASE WHEN @Sortby = 'Customer' THEN p.PayeeName END,
        CASE WHEN @Sortby = 'Total' THEN p.PayeeTotalDue END DESC,
        p.PayeeName; -- default fallback
END

