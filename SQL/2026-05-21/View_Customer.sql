SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [dbo].[View_Customer] AS
/*
  AR customer view — real-time per-customer AR snapshot.

  Aging math is inline DATEDIFF over open Sales rows (filtered by ShipId = PayeeId
  and AmountDue <> 0). Stored Sales.Aging and Sales.InvoiceAging are NOT used here;
  every bucket is recomputed at query time.

  Rules followed:
    Rule 1 — AR aggregation key is Sales.ShipId. BillId is the corp payment module's
             concern, not this view's.
    Rule 2 — All aging buckets are real-time (no SUM over stored aging columns).
    Rule 3 — Column shape: 5 due-date buckets + 4 invoice-date buckets (no Payee5,
             InvoiceAgeCurrent, or InvoiceAge5 — those were view-only and are removed).
    Rule 4 — FirstDueDate = MIN(DueDate). The earlier MIN(ShipDate) semantic was
             misnamed; AR-side fix this round, AP side (View_Vendor) deferred.
    Rule 5 — Cached Payee.* fields the view still surfaces (AvgPaymentDays,
             IsCreditHold, Payee30Volume implicitly via Customer_GetAllList) stay
             written by Payee_UpdateAging using matching math.

  Invoice-date basis = ShipDate. Due-date basis = DueDate.
  DATEDIFF > 0 means past that date; DATEDIFF <= 0 means today or future.
*/
SELECT
    p.PayeeId,
    p.PayeeName,
    p.TermId,
    c.SalesRepId,
    c.Region,
    c.DefaultRoute,
    t.TermName,
    c.IsAutoPayment,
    (SELECT COUNT(*) FROM dbo.PaymentMethod pm WHERE pm.PayeeId = p.PayeeId) AS PaymentMethodCount,
    (SELECT ISNULL(PayeeName, '') FROM dbo.Payee WHERE PayeeId = c.SalesRepId) AS SalesRepName,

    -- Due-date aging buckets (5)
    ISNULL(AR.PayeeCurrent, 0)    AS PayeeCurrent,
    ISNULL(AR.Payee30, 0)         AS Payee30,
    ISNULL(AR.Payee60, 0)         AS Payee60,
    ISNULL(AR.Payee90, 0)         AS Payee90,
    ISNULL(AR.PayeeOver90, 0)     AS PayeeOver90,
    ISNULL(AR.MaxDueAgingDays, 0) AS MaxDueAgingDays,

    -- Invoice-date aging buckets (4)
    ISNULL(AR.InvoiceAge30, 0)     AS InvoiceAge30,
    ISNULL(AR.InvoiceAge60, 0)     AS InvoiceAge60,
    ISNULL(AR.InvoiceAge90, 0)     AS InvoiceAge90,
    ISNULL(AR.InvoiceAgeOver90, 0) AS InvoiceAgeOver90,
    ISNULL(AR.DueInvoiceDays, 0)   AS DueInvoiceDays,

    -- Totals & balance
    ISNULL(AR.PayeeTotalDue, 0) AS PayeeTotalDue,
    ISNULL(AR.PayeePastDue, 0)  AS PayeePastDue,
    ISNULL(AR.PayeeTotalDue, 0) - ISNULL(UC.UnappliedTotal, 0) AS Balance,
    AR.FirstDueDate,

    p.GracePeriod,

    -- Last payment
    LP.LastPaymentDate,
    CASE WHEN LP.LastPaymentDate IS NULL
         THEN NULL
         ELSE DATEDIFF(DAY, LP.LastPaymentDate, GETDATE())
    END AS LastPaidDaysAgo,
    LP.LastPaymentAmount,

    -- Last order
    LO.LastOrderDate,
    CASE WHEN LO.LastOrderDate IS NULL
         THEN NULL
         ELSE DATEDIFF(DAY, LO.LastOrderDate, GETDATE())
    END AS LastOrderDaysAgo,
    LO.LastOrderAmount,

    -- Cached (Payee_UpdateAging owns; view just surfaces)
    p.AvgPaymentDays,
    p.IsCreditHold
FROM dbo.Payee AS p
INNER JOIN dbo.Customer AS c ON p.PayeeId = c.PayeeId
LEFT JOIN dbo.Term AS t ON t.TermId = p.TermId

-- Consolidated AR aggregate: single scan over this customer's open Sales rows.
-- Both due-date and invoice-date buckets are computed in this one APPLY so we
-- don't double-scan the same set (the old view used two separate APPLYs).
OUTER APPLY
(
    SELECT
        -- Due-date buckets
        SUM(CASE WHEN DATEDIFF(DAY, s.DueDate, GETDATE()) <= 0              THEN s.AmountDue ELSE 0 END) AS PayeeCurrent,
        SUM(CASE WHEN DATEDIFF(DAY, s.DueDate, GETDATE()) BETWEEN 1  AND 30 THEN s.AmountDue ELSE 0 END) AS Payee30,
        SUM(CASE WHEN DATEDIFF(DAY, s.DueDate, GETDATE()) BETWEEN 31 AND 60 THEN s.AmountDue ELSE 0 END) AS Payee60,
        SUM(CASE WHEN DATEDIFF(DAY, s.DueDate, GETDATE()) BETWEEN 61 AND 90 THEN s.AmountDue ELSE 0 END) AS Payee90,
        SUM(CASE WHEN DATEDIFF(DAY, s.DueDate, GETDATE()) > 90              THEN s.AmountDue ELSE 0 END) AS PayeeOver90,

        -- Invoice-date buckets
        SUM(CASE WHEN DATEDIFF(DAY, s.ShipDate, GETDATE()) BETWEEN 0  AND 30 THEN s.AmountDue ELSE 0 END) AS InvoiceAge30,
        SUM(CASE WHEN DATEDIFF(DAY, s.ShipDate, GETDATE()) BETWEEN 31 AND 60 THEN s.AmountDue ELSE 0 END) AS InvoiceAge60,
        SUM(CASE WHEN DATEDIFF(DAY, s.ShipDate, GETDATE()) BETWEEN 61 AND 90 THEN s.AmountDue ELSE 0 END) AS InvoiceAge90,
        SUM(CASE WHEN DATEDIFF(DAY, s.ShipDate, GETDATE()) > 90              THEN s.AmountDue ELSE 0 END) AS InvoiceAgeOver90,

        -- Totals and dates
        SUM(s.AmountDue)                                                                                  AS PayeeTotalDue,
        SUM(CASE WHEN s.DueDate < CAST(GETDATE() AS DATE) THEN s.AmountDue ELSE 0 END)                    AS PayeePastDue,
        MIN(s.DueDate)                                                                                    AS FirstDueDate,

        -- Max days past due (clamped at 0 when nothing is past due)
        MAX(CASE WHEN DATEDIFF(DAY, s.DueDate, GETDATE()) > 0
                 THEN DATEDIFF(DAY, s.DueDate, GETDATE())
                 ELSE 0 END)                                                                              AS MaxDueAgingDays,
        -- Max days since invoice was shipped (always >= 0 for shipped open invoices)
        MAX(DATEDIFF(DAY, s.ShipDate, GETDATE()))                                                         AS DueInvoiceDays
    FROM dbo.Sales s
    WHERE s.ShipId = p.PayeeId
      AND s.AmountDue <> 0
) AS AR

-- Last positive Sales (most recent order)
OUTER APPLY
(
    SELECT TOP (1)
        s.ShipDate   AS LastOrderDate,
        s.SalesTotal AS LastOrderAmount
    FROM dbo.Sales s
    WHERE s.ShipId = p.PayeeId
      AND s.SalesTotal > 0
    ORDER BY s.ShipDate DESC, s.SalesId DESC
) AS LO

-- Last customer payment
OUTER APPLY
(
    SELECT TOP (1)
        cp.PaymentDate   AS LastPaymentDate,
        cp.PaymentAmount AS LastPaymentAmount
    FROM dbo.CustomerPayment cp
    WHERE cp.PayeeId = p.PayeeId
    ORDER BY cp.PaymentDate DESC, cp.CustomerPaymentId DESC
) AS LP

-- Unapplied credits (used in Balance = PayeeTotalDue - Unapplied)
OUTER APPLY
(
    SELECT SUM(cp.UnappliedAmount) AS UnappliedTotal
    FROM dbo.CustomerPayment cp
    WHERE cp.PayeeId = p.PayeeId
      AND cp.UnappliedAmount <> 0
      AND cp.IsReturned = 0
) AS UC;
GO
