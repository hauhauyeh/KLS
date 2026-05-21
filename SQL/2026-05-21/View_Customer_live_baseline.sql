
-- Add SalesRepId to View_Customer so AR list procedures can filter by sales rep.

CREATE VIEW [dbo].[View_Customer] AS
SELECT
    p.PayeeId,
    p.PayeeName,
    p.TermId,
    c.SalesRepId,
    c.Region,
    c.DefaultRoute,
    t.TermName,
    c.IsAutoPayment,
    (
        SELECT COUNT(*)
        FROM PaymentMethod pm
        WHERE pm.PayeeId = p.PayeeId
    ) AS PaymentMethodCount,
    (
        SELECT ISNULL(PayeeName, '')
        FROM Payee
        WHERE PayeeId = c.SalesRepId
    ) AS SalesRepName,

    ISNULL(DA.DueAgeCurrent, 0) AS PayeeCurrent,
    ISNULL(DA.DueAge5, 0) AS Payee5,
    ISNULL(DA.DueAge30, 0) AS Payee30,
    ISNULL(p.Payee60, 0) AS Payee60,
    ISNULL(p.Payee90, 0) AS Payee90,
    ISNULL(p.PayeeOver90, 0) AS PayeeOver90,
    ISNULL(DA.MaxDueAgingDays, 0) AS MaxDueAgingDays,

    ISNULL(IA.InvoiceAgeCurrent, 0) AS InvoiceAgeCurrent,
    ISNULL(IA.InvoiceAge5, 0) AS InvoiceAge5,
    ISNULL(IA.InvoiceAge30, 0) AS InvoiceAge30,
    ISNULL(p.Invoice60, 0) AS InvoiceAge60,
    ISNULL(p.Invoice90, 0) AS InvoiceAge90,
    ISNULL(p.PayeeOver90, 0) AS InvoiceAgeOver90,
    ISNULL(IA.MaxInvAgingDays, 0) AS DueInvoiceDays,

    p.PayeeTotalDue,
    p.PayeePastDue,
    p.Balance,
    p.GracePeriod,
    p.LastPaymentDate,
    CASE
        WHEN p.LastPaymentDate IS NULL THEN NULL
        ELSE DATEDIFF(DAY, p.LastPaymentDate, GETDATE())
    END AS LastPaidDaysAgo,
    p.LastPaymentAmount,
    p.LastOrderDate,
    CASE
        WHEN p.LastOrderDate IS NULL THEN NULL
        ELSE DATEDIFF(DAY, p.LastOrderDate, GETDATE())
    END AS LastOrderDaysAgo,
    p.LastOrderAmount,
    p.FirstDueDate,
    p.AvgPaymentDays,
    p.IsCreditHold
FROM Payee AS p
INNER JOIN Customer AS c
    ON p.PayeeId = c.PayeeId
LEFT JOIN Term AS t
    ON t.TermId = p.TermId
OUTER APPLY
(
    SELECT
        SUM(CASE WHEN s.Aging = 0 THEN s.AmountDue ELSE 0 END) AS DueAgeCurrent,
        SUM(CASE WHEN s.Aging BETWEEN 1 AND 5 THEN s.AmountDue ELSE 0 END) AS DueAge5,
        SUM(CASE WHEN s.Aging BETWEEN 6 AND 30 THEN s.AmountDue ELSE 0 END) AS DueAge30,
        --SUM(CASE WHEN s.Aging BETWEEN 31 AND 60 THEN s.AmountDue ELSE 0 END) AS DueAge60,
        --SUM(CASE WHEN s.Aging BETWEEN 61 AND 90 THEN s.AmountDue ELSE 0 END) AS DueAge90,
        --SUM(CASE WHEN s.Aging > 90 THEN s.AmountDue ELSE 0 END) AS DueAgeOver90,
        MAX(s.Aging) AS MaxDueAgingDays
    FROM dbo.Sales s
    WHERE s.ShipId = p.PayeeId
      AND s.AmountDue <> 0
) AS DA
OUTER APPLY
(
    SELECT
        SUM(CASE WHEN s.InvoiceAging = 0 THEN s.AmountDue ELSE 0 END) AS InvoiceAgeCurrent,
        SUM(CASE WHEN s.InvoiceAging BETWEEN 1 AND 5 THEN s.AmountDue ELSE 0 END) AS InvoiceAge5,
        SUM(CASE WHEN s.InvoiceAging BETWEEN 6 AND 30 THEN s.AmountDue ELSE 0 END) AS InvoiceAge30,
        --SUM(CASE WHEN s.InvoiceAging BETWEEN 31 AND 60 THEN s.AmountDue ELSE 0 END) AS InvoiceAge60,
        --SUM(CASE WHEN s.InvoiceAging BETWEEN 61 AND 90 THEN s.AmountDue ELSE 0 END) AS InvoiceAge90,
        --SUM(CASE WHEN s.InvoiceAging > 90 THEN s.AmountDue ELSE 0 END) AS InvoiceAgeOver90,
        MAX(s.InvoiceAging) AS MaxInvAgingDays
    FROM dbo.Sales s
    WHERE s.ShipId = p.PayeeId
      AND s.AmountDue <> 0
) AS IA;

