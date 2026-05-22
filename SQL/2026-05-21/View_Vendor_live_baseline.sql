

CREATE VIEW [dbo].[View_Vendor] AS

SELECT 
p.PayeeId,
p.PayeeName,
t.TermName,
p.PayeeCurrent,
p.Payee30,
p.Payee60,
p.Payee90,
p.PayeeOver90,
p.PayeeTotalDue,
p.PayeePastDue,
p.Balance,
p.MaxInvoiceAgingDays AS DueInvoiceDays,
p.LastPaymentDate,
CASE WHEN p.LastPaymentDate IS NULL THEN NULL ELSE DATEDIFF(DAY, p.LastPaymentDate, GETDATE()) END 
AS LastPaidDaysAgo,
p.LastPaymentAmount,
p.LastOrderDate,
CASE WHEN p.LastOrderDate IS NULL THEN NULL ELSE DATEDIFF(DAY, p.LastOrderDate, GETDATE()) END AS LastOrderDaysAgo,
p.LastOrderAmount,
p.FirstDueDate,
p.AvgPaymentDays

FROM Payee AS p 
INNER JOIN Vendor as v ON p.PayeeId=v.PayeeId
LEFT JOIN Term AS t ON t.TermId=p.TermId
WHERE PayeeType='V'


