-- Rollback: Restore original View_Customer (without InvoiceAging columns, with old subqueries)
ALTER VIEW [dbo].[View_Customer] AS
SELECT
p.PayeeId,
p.PayeeName,
c.Region,
c.DefaultRoute,
t.TermName,
c.IsAutoPayment,
(SELECT COUNT(*) FROM PaymentMethod as pm WHERE pm.PayeeId=P.PayeeId) AS PaymentMethodCount,
(SELECT ISNULL(PayeeName, '') FROM Payee WHERE (PayeeId = c.SalesRepId)) AS SalesRepName,
p.PayeeCurrent,
(SELECT SUM(AmountDue) FROM Sales AS s WHERE (Aging >= 1) AND (Aging <= 5) AND (ShipId = P.PayeeId)) AS Payee5,
(SELECT SUM(AmountDue) FROM Sales AS s WHERE (Aging >= 6) AND (Aging <= 30) AND (ShipId = P.PayeeId)) AS Payee30,
p.Payee60,
p.Payee90,
p.PayeeOver90,
p.PayeeTotalDue,
p.PayeePastDue,
p.Balance,
p.GracePeriod,
p.MaxInvoiceAgingDays AS DueInvoiceDays,
p.LastPaymentDate,
CASE WHEN p.LastPaymentDate IS NULL THEN NULL ELSE DATEDIFF(DAY, p.LastPaymentDate, GETDATE()) END AS LastPaidDaysAgo,
p.LastPaymentAmount,
p.LastOrderDate,
CASE WHEN p.LastOrderDate IS NULL THEN NULL ELSE DATEDIFF(DAY, p.LastOrderDate, GETDATE()) END AS LastOrderDaysAgo,
p.LastOrderAmount,
p.FirstDueDate,
p.AvgPaymentDays,
p.IsCreditHold
FROM Payee AS p
INNER JOIN Customer as c ON p.PayeeId=c.PayeeId
LEFT JOIN Term AS t ON t.TermId=p.TermId
GO
