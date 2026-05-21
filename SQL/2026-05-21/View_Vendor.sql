SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [dbo].[View_Vendor] AS
/*
  AP vendor view — real-time per-vendor AP snapshot.

  Aging math is inline DATEDIFF over open Purchase rows (filtered by
  PayeeId = Payee.PayeeId and AmountDue <> 0). Stored Purchase.Aging and
  Purchase.InvoiceAging are NOT used here:
    - Purchase.InvoiceAging is bugged (DueDate-based despite the name) — see
      Bug A in view-vendor-realtime-aging-plan.md.
    - Purchase.Aging is also stored / refreshed periodically; we'd rather
      compute live than risk staleness.

  Rules followed (same as View_Customer):
    Rule 1 — AP aggregation key is Purchase.PayeeId. No Bill/Ship split exists
             on Purchase; nothing corp-payment-module-like to consider here.
    Rule 2 — All aging buckets are real-time (no SUM over stored aging columns).
    Rule 3 — 5 due-date buckets + 4 invoice-date buckets, same shape as
             View_Customer. (Original View_Vendor surfaced only the 5 due-date
             buckets; invoice-date buckets are newly added here.)
    Rule 4 — FirstDueDate = MIN(DueDate). Was MIN(ArrivalDate) in the cache
             writer; AP branch of Payee_UpdateAging is being fixed in the same
             round.
    Rule 5 — Cached Payee.* AP fields (AvgPaymentDays) still read from Payee;
             Payee_UpdateAging AP branch writes them with matching math.

  Invoice-date basis = ISNULL(p.InvoiceDate, p.PurchaseDate).
  Due-date basis = p.DueDate.
*/
SELECT
    p.PayeeId,
    p.PayeeName,
    t.TermName,

    -- Due-date aging buckets (5)
    ISNULL(AP.PayeeCurrent, 0)    AS PayeeCurrent,
    ISNULL(AP.Payee30, 0)         AS Payee30,
    ISNULL(AP.Payee60, 0)         AS Payee60,
    ISNULL(AP.Payee90, 0)         AS Payee90,
    ISNULL(AP.PayeeOver90, 0)     AS PayeeOver90,
    ISNULL(AP.MaxDueAgingDays, 0) AS MaxDueAgingDays,

    -- Invoice-date aging buckets (4)  -- new in this round
    ISNULL(AP.InvoiceAge30, 0)     AS InvoiceAge30,
    ISNULL(AP.InvoiceAge60, 0)     AS InvoiceAge60,
    ISNULL(AP.InvoiceAge90, 0)     AS InvoiceAge90,
    ISNULL(AP.InvoiceAgeOver90, 0) AS InvoiceAgeOver90,
    ISNULL(AP.DueInvoiceDays, 0)   AS DueInvoiceDays,

    -- Totals & balance
    ISNULL(AP.PayeeTotalDue, 0) AS PayeeTotalDue,
    ISNULL(AP.PayeePastDue, 0)  AS PayeePastDue,
    ISNULL(AP.PayeeTotalDue, 0) AS Balance,    -- AP: no UnappliedAmount on VendorPayment
    AP.FirstDueDate,

    -- Last payment
    LP.LastPaymentDate,
    CASE WHEN LP.LastPaymentDate IS NULL
         THEN NULL
         ELSE DATEDIFF(DAY, LP.LastPaymentDate, GETDATE())
    END AS LastPaidDaysAgo,
    LP.LastPaymentAmount,

    -- Last order (vendor delivery)
    LO.LastOrderDate,
    CASE WHEN LO.LastOrderDate IS NULL
         THEN NULL
         ELSE DATEDIFF(DAY, LO.LastOrderDate, GETDATE())
    END AS LastOrderDaysAgo,
    LO.LastOrderAmount,

    -- Cached (Payee_UpdateAging AP branch owns; view just surfaces)
    p.AvgPaymentDays
FROM dbo.Payee AS p
INNER JOIN dbo.Vendor AS v ON p.PayeeId = v.PayeeId
LEFT JOIN dbo.Term AS t ON t.TermId = p.TermId

-- Consolidated AP aggregate: single scan over this vendor's open Purchase rows.
OUTER APPLY
(
    SELECT
        -- Due-date buckets
        SUM(CASE WHEN DATEDIFF(DAY, pu.DueDate, GETDATE()) <= 0              THEN pu.AmountDue ELSE 0 END) AS PayeeCurrent,
        SUM(CASE WHEN DATEDIFF(DAY, pu.DueDate, GETDATE()) BETWEEN 1  AND 30 THEN pu.AmountDue ELSE 0 END) AS Payee30,
        SUM(CASE WHEN DATEDIFF(DAY, pu.DueDate, GETDATE()) BETWEEN 31 AND 60 THEN pu.AmountDue ELSE 0 END) AS Payee60,
        SUM(CASE WHEN DATEDIFF(DAY, pu.DueDate, GETDATE()) BETWEEN 61 AND 90 THEN pu.AmountDue ELSE 0 END) AS Payee90,
        SUM(CASE WHEN DATEDIFF(DAY, pu.DueDate, GETDATE()) > 90              THEN pu.AmountDue ELSE 0 END) AS PayeeOver90,

        -- Invoice-date buckets (ISNULL fallback: vendor invoice date if present, else our purchase date)
        SUM(CASE WHEN DATEDIFF(DAY, ISNULL(pu.InvoiceDate, pu.PurchaseDate), GETDATE()) BETWEEN 0  AND 30 THEN pu.AmountDue ELSE 0 END) AS InvoiceAge30,
        SUM(CASE WHEN DATEDIFF(DAY, ISNULL(pu.InvoiceDate, pu.PurchaseDate), GETDATE()) BETWEEN 31 AND 60 THEN pu.AmountDue ELSE 0 END) AS InvoiceAge60,
        SUM(CASE WHEN DATEDIFF(DAY, ISNULL(pu.InvoiceDate, pu.PurchaseDate), GETDATE()) BETWEEN 61 AND 90 THEN pu.AmountDue ELSE 0 END) AS InvoiceAge90,
        SUM(CASE WHEN DATEDIFF(DAY, ISNULL(pu.InvoiceDate, pu.PurchaseDate), GETDATE()) > 90              THEN pu.AmountDue ELSE 0 END) AS InvoiceAgeOver90,

        -- Totals and dates
        SUM(pu.AmountDue)                                                                                   AS PayeeTotalDue,
        SUM(CASE WHEN pu.DueDate < CAST(GETDATE() AS DATE) THEN pu.AmountDue ELSE 0 END)                    AS PayeePastDue,
        MIN(pu.DueDate)                                                                                     AS FirstDueDate,

        -- Max days past due (clamped at 0)
        MAX(CASE WHEN DATEDIFF(DAY, pu.DueDate, GETDATE()) > 0
                 THEN DATEDIFF(DAY, pu.DueDate, GETDATE())
                 ELSE 0 END)                                                                                AS MaxDueAgingDays,
        -- Max days since invoice (always >= 0 for open vendor invoices)
        MAX(DATEDIFF(DAY, ISNULL(pu.InvoiceDate, pu.PurchaseDate), GETDATE()))                              AS DueInvoiceDays
    FROM dbo.Purchase pu
    WHERE pu.PayeeId = p.PayeeId
      AND pu.AmountDue <> 0
) AS AP

-- Last positive Purchase (most recent delivery)
OUTER APPLY
(
    SELECT TOP (1)
        pu.ArrivalDate   AS LastOrderDate,
        pu.PurchaseTotal AS LastOrderAmount
    FROM dbo.Purchase pu
    WHERE pu.PayeeId = p.PayeeId
      AND pu.PurchaseTotal > 0
    ORDER BY pu.ArrivalDate DESC, pu.PurchaseId DESC
) AS LO

-- Last vendor payment
OUTER APPLY
(
    SELECT TOP (1)
        vp.PaymentDate   AS LastPaymentDate,
        vp.PaymentAmount AS LastPaymentAmount
    FROM dbo.VendorPayment vp
    WHERE vp.PayeeId = p.PayeeId
    ORDER BY vp.PaymentDate DESC, vp.VendorPaymentId DESC
) AS LP
WHERE p.PayeeType = 'V';
GO
