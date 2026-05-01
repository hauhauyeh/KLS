-- Add InvoiceAging buckets to View_Customer
-- Replaces old mixed approach (cached Payee fields + live subqueries) with
-- two parallel OUTER APPLYs for consistent data in both aging modes.

ALTER VIEW [dbo].[View_Customer] AS
SELECT
    p.PayeeId, p.PayeeName, c.Region, c.DefaultRoute, t.TermName,
    c.IsAutoPayment,
    (SELECT COUNT(*) FROM PaymentMethod pm WHERE pm.PayeeId = P.PayeeId) AS PaymentMethodCount,
    (SELECT ISNULL(PayeeName, '') FROM Payee WHERE PayeeId = c.SalesRepId) AS SalesRepName,

    -- Due Date aging (live from Sales)
    ISNULL(DA.DueAgeCurrent, 0) AS PayeeCurrent,
    ISNULL(DA.DueAge5, 0) AS Payee5,
    ISNULL(DA.DueAge30, 0) AS Payee30,
    ISNULL(DA.DueAge60, 0) AS Payee60,
    ISNULL(DA.DueAge90, 0) AS Payee90,
    ISNULL(DA.DueAgeOver90, 0) AS PayeeOver90,

    -- Invoice Date aging (live from Sales)
    ISNULL(IA.InvoiceAgeCurrent, 0) AS InvoiceAgeCurrent,
    ISNULL(IA.InvoiceAge5, 0) AS InvoiceAge5,
    ISNULL(IA.InvoiceAge30, 0) AS InvoiceAge30,
    ISNULL(IA.InvoiceAge60, 0) AS InvoiceAge60,
    ISNULL(IA.InvoiceAge90, 0) AS InvoiceAge90,
    ISNULL(IA.InvoiceAgeOver90, 0) AS InvoiceAgeOver90,

    p.PayeeTotalDue, p.PayeePastDue, p.Balance, p.GracePeriod,
    p.MaxInvoiceAgingDays AS DueInvoiceDays,
    p.LastPaymentDate,
    CASE WHEN p.LastPaymentDate IS NULL THEN NULL
         ELSE DATEDIFF(DAY, p.LastPaymentDate, GETDATE()) END AS LastPaidDaysAgo,
    p.LastPaymentAmount, p.LastOrderDate,
    CASE WHEN p.LastOrderDate IS NULL THEN NULL
         ELSE DATEDIFF(DAY, p.LastOrderDate, GETDATE()) END AS LastOrderDaysAgo,
    p.LastOrderAmount, p.FirstDueDate, p.AvgPaymentDays, p.IsCreditHold

FROM Payee AS p
INNER JOIN Customer AS c ON p.PayeeId = c.PayeeId
LEFT JOIN Term AS t ON t.TermId = p.TermId
OUTER APPLY (
    SELECT
        SUM(CASE WHEN s.Aging = 0 THEN s.AmountDue ELSE 0 END) AS DueAgeCurrent,
        SUM(CASE WHEN s.Aging BETWEEN 1 AND 5 THEN s.AmountDue ELSE 0 END) AS DueAge5,
        SUM(CASE WHEN s.Aging BETWEEN 6 AND 30 THEN s.AmountDue ELSE 0 END) AS DueAge30,
        SUM(CASE WHEN s.Aging BETWEEN 31 AND 60 THEN s.AmountDue ELSE 0 END) AS DueAge60,
        SUM(CASE WHEN s.Aging BETWEEN 61 AND 90 THEN s.AmountDue ELSE 0 END) AS DueAge90,
        SUM(CASE WHEN s.Aging > 90 THEN s.AmountDue ELSE 0 END) AS DueAgeOver90
    FROM dbo.Sales s WHERE s.ShipId = p.PayeeId AND s.AmountDue <> 0
) DA
OUTER APPLY (
    SELECT
        SUM(CASE WHEN s.InvoiceAging = 0 THEN s.AmountDue ELSE 0 END) AS InvoiceAgeCurrent,
        SUM(CASE WHEN s.InvoiceAging BETWEEN 1 AND 5 THEN s.AmountDue ELSE 0 END) AS InvoiceAge5,
        SUM(CASE WHEN s.InvoiceAging BETWEEN 6 AND 30 THEN s.AmountDue ELSE 0 END) AS InvoiceAge30,
        SUM(CASE WHEN s.InvoiceAging BETWEEN 31 AND 60 THEN s.AmountDue ELSE 0 END) AS InvoiceAge60,
        SUM(CASE WHEN s.InvoiceAging BETWEEN 61 AND 90 THEN s.AmountDue ELSE 0 END) AS InvoiceAge90,
        SUM(CASE WHEN s.InvoiceAging > 90 THEN s.AmountDue ELSE 0 END) AS InvoiceAgeOver90
    FROM dbo.Sales s WHERE s.ShipId = p.PayeeId AND s.AmountDue <> 0
) IA
GO
