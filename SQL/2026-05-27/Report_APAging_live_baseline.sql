SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Report_APAging];
GO


CREATE PROCEDURE [dbo].[Report_APAging] -- EXEC Report_APAging @AsOfDate='2026-05-25',@AgeBasis='DueDate'
-- EXEC Report_APAging @AsOfDate='2026-05-25',@AgeBasis='InvoiceDate'
-- EXEC Report_APAging @AsOfDate='2026-05-25',@AgeBasis='DueDate',@VendorId=200166
-- EXEC Report_APAging @AsOfDate='2026-05-25',@AgeBasis='DueDate',@TermId=24
    @AsOfDate  DATE,
    @AgeBasis  NVARCHAR(20),     -- 'DueDate' | 'InvoiceDate'
    @VendorId  INT          = NULL,
    @TermId    INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Defaults: As-of = today, basis = DueDate. Callers that pass NULL
    -- still get a sensible report instead of an empty result.
    IF @AsOfDate IS NULL  SET @AsOfDate = CAST(GETDATE() AS DATE);
    IF @AgeBasis IS NULL  SET @AgeBasis = 'DueDate';

    -- Hard-fail unknown basis values rather than silently returning 0 rows.
    -- Frontend always sends one of these two; bad input means a bug upstream.
    IF @AgeBasis NOT IN ('DueDate','InvoiceDate')
        THROW 50001, 'AgeBasis must be DueDate or InvoiceDate', 1;

    /*
        Per-invoice AP Aging — open balance only, billed bills only.

        Source rules (locked in the plan and the central bug fix):
          - Purchase.StageId = 6 ('Billed') only. Pre-Billed stages (Ordered,
            Partially Shipped, Shipped, Partially Received, Received) are not
            real AP — no vendor invoice received, no due date, no AP owed.
          - Purchase.AmountDue <> 0. Closed bills (AmountDue = 0) excluded
            by definition; this is "AP Aging", not a historical bill diagnostic.
          - PayeeType = 'V'. Vendor Payee rows only — Customer / Employee
            payees never have Purchase rows, but the filter is cheap belt-and-suspenders.

        Two-pass shape: BillRows CTE computes AgeDays once based on @AgeBasis,
        then the outer SELECT derives the Bucket label + 5 mirror columns from
        AgeDays. Mirror columns (BucketCurrent / Bucket30 / ... / BucketOver90)
        carry AmountDue in the row's own bucket and 0 elsewhere, so the frontend
        can SUM each column for vendor subtotals + grand totals without a switch.

        AgeDays sign convention:
          DueDate basis    — AgeDays < 0 means "not yet due" (DueDate is in the future)
                             AgeDays >= 0 means "past due by N days" (DueDate <= @AsOfDate)
          InvoiceDate basis — AgeDays is always >= 0 in practice
                              (invoices aren't dated in the future).

        DueDate fallback: if DueDate is NULL on a Billed row (rare, but possible
        from older imports), fall back to InvoiceDate so the row still buckets
        instead of throwing or landing in 'Over 90' from a NULL DATEDIFF.

        Term column comes from Payee.TermId (the vendor's default term), not
        Purchase.TermId (per-bill override). Mutual-exclusivity decision with
        the @VendorId filter: picking a Vendor implies their Term, so the
        @TermId filter is essentially redundant when @VendorId is set —
        the frontend disables the Term dropdown when a Vendor is chosen.
    */
    ;WITH BillRows AS
    (
        SELECT
            p.PurchaseId,
            p.PayeeId,
            pe.PayeeName,
            pe.TermId,                                  -- Payee's default term (not per-bill override)
            p.PurchaseNumber,
            p.VendorDocNumber,
            p.ContainerNumber,
            p.InvoiceDate,
            p.DueDate,
            p.PurchaseTotal,
            p.AmountDue,
            DATEDIFF(DAY,
                CASE @AgeBasis
                    WHEN 'DueDate'     THEN ISNULL(p.DueDate, p.InvoiceDate)
                    WHEN 'InvoiceDate' THEN p.InvoiceDate
                END,
                @AsOfDate
            ) AS AgeDays
        FROM dbo.Purchase p
        INNER JOIN dbo.Payee pe ON pe.PayeeId = p.PayeeId
        WHERE pe.PayeeType = 'V'
          AND p.StageId    = 6                          -- 'Billed' only — pre-Billed rows aren't real AP
          AND p.AmountDue <> 0                          -- open balance only; closed bills excluded by report definition
          AND (@VendorId IS NULL OR pe.PayeeId = @VendorId)
          AND (@TermId   IS NULL OR pe.TermId  = @TermId)
    )
    SELECT
        b.PurchaseId,
        b.PayeeId,
        b.PayeeName         AS Vendor,
        b.PurchaseNumber,
        b.VendorDocNumber   AS InvoiceNumber,           -- vendor's printed invoice number
        b.ContainerNumber,                              -- container / shipment / PO reference (free-form)
        b.InvoiceDate,
        b.DueDate,
        t.TermName          AS Term,
        b.PurchaseTotal     AS OriginalAmount,
        b.AmountDue         AS OpenBalance,
        b.AgeDays,

        -- Bucket label. Same column names work for both bases; only the
        -- first-numeric-bucket label differs ('1-30' for DueDate vs '0-30'
        -- for InvoiceDate). Frontend can render the label as-is.
        CASE
            WHEN @AgeBasis = 'DueDate' AND b.AgeDays < 0 THEN 'Current'
            WHEN b.AgeDays <= 30 THEN CASE @AgeBasis WHEN 'DueDate' THEN '1-30' ELSE '0-30' END
            WHEN b.AgeDays <= 60 THEN '31-60'
            WHEN b.AgeDays <= 90 THEN '61-90'
            ELSE                       'Over 90'
        END AS Bucket,

        -- Mirror columns — one bucket gets AmountDue, the rest get 0. Lets the
        -- frontend SUM(BucketXxx) per vendor for subtotals without a JS switch.
        CASE WHEN @AgeBasis = 'DueDate' AND b.AgeDays < 0 THEN b.AmountDue ELSE 0 END AS BucketCurrent,
        CASE WHEN NOT (@AgeBasis = 'DueDate' AND b.AgeDays < 0) AND b.AgeDays <= 30 THEN b.AmountDue ELSE 0 END AS Bucket30,
        CASE WHEN b.AgeDays BETWEEN 31 AND 60 THEN b.AmountDue ELSE 0 END AS Bucket60,
        CASE WHEN b.AgeDays BETWEEN 61 AND 90 THEN b.AmountDue ELSE 0 END AS Bucket90,
        CASE WHEN b.AgeDays > 90              THEN b.AmountDue ELSE 0 END AS BucketOver90,

        -- IsCredit flag — frontend uses it to section CM bills (negative
        -- AmountDue) into a separate "Credits" group below the AP detail when
        -- the user toggles "Show Credits Separately" on. The SP returns the
        -- same data regardless of that toggle; sectioning is purely a render
        -- decision so the SP signature stays minimal.
        CASE WHEN b.AmountDue < 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCredit

    FROM BillRows b
    LEFT JOIN dbo.Term t ON t.TermId = b.TermId
    ORDER BY
        b.PayeeName,
        -- Oldest first within vendor — earliest source date = highest AgeDays.
        CASE @AgeBasis
            WHEN 'DueDate'     THEN ISNULL(b.DueDate, b.InvoiceDate)
            WHEN 'InvoiceDate' THEN b.InvoiceDate
        END;
END


GO
