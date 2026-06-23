SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Report_ARAging];
GO

CREATE PROCEDURE [dbo].[Report_ARAging] -- EXEC Report_ARAging @AsOfDate='2026-06-09',@AgeBasis='DueDate'
-- EXEC Report_ARAging @AsOfDate='2026-06-09',@AgeBasis='InvoiceDate'
-- EXEC Report_ARAging @AsOfDate='2026-06-09',@AgeBasis='DueDate',@CustomerId=304036
-- EXEC Report_ARAging @AsOfDate='2026-06-09',@AgeBasis='DueDate',@TermId=24
-- EXEC Report_ARAging @AsOfDate='2026-06-09',@AgeBasis='DueDate',@SalesRepId=12
    @AsOfDate   DATE,
    @AgeBasis   NVARCHAR(20),     -- 'DueDate' | 'InvoiceDate'
    @CustomerId INT          = NULL,
    @TermId     INT          = NULL,
    @SalesRepId INT          = NULL
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
        Per-invoice AR Aging — open balance only, customer-side.

        Source rules:
          - Sales.AmountDue <> 0. Closed sales (AmountDue = 0) excluded
            by definition; this is "AR Aging", not a sales-history report.
          - PayeeType = 'C'. Customer Payee rows only — Vendor / Employee
            payees never have Sales rows, but the filter is cheap belt-and-suspenders.
          - NO StageId filter (deliberate). The report matches what
            View_Customer aggregates: any Sales with AmountDue <> 0 counts as
            real AR regardless of stage. Parity is verified at deploy by
            comparing SUM(OpenBalance) to View_Customer aggregates.

        Ownership = ShipId (NOT BillId). The portal authenticates by ShipId
        and admin AR aggregates by ShipId (per project_ar_ap_aging_architecture
        memory). All customer-level joins use Payee.PayeeId = s.ShipId so the
        identity stays consistent across the row. BillId is reserved for the
        separate Corporate Payment workflow.

        Two-pass shape: BillRows CTE computes AgeDays once based on @AgeBasis,
        then the outer SELECT derives the Bucket label + 5 mirror columns from
        AgeDays. Mirror columns (BucketCurrent / Bucket30 / ... / BucketOver90)
        carry AmountDue in the row's own bucket and 0 elsewhere, so the frontend
        can SUM each column for customer subtotals + grand totals without a switch.

        AgeDays sign convention:
          DueDate basis    — AgeDays < 0 means "not yet due" (DueDate in the future)
                             AgeDays >= 0 means "past due by N days" (DueDate <= @AsOfDate)
          InvoiceDate basis — AgeDays is always >= 0 in practice
                              (invoices aren't dated in the future).

        DueDate fallback: if DueDate is NULL on a Sales row (rare, but possible
        from older imports or specific stages), fall back to ShipDate so the row
        still buckets instead of throwing or landing in 'Over 90' from a NULL
        DATEDIFF.

        Term column comes from Payee.TermId (the customer's default term), not
        Sales.TermId (per-document override). Mutual-exclusivity with @CustomerId:
        picking a Customer implies their Term, so the frontend disables the Term
        dropdown when a Customer is chosen.

        LastPaymentDate / LastPaymentAmount come from Payee (joined on ShipId).
        Denormalized per row — every row for the same customer carries the same
        value. Frontend reads from the group's first row only and renders in
        the group header, NOT in the per-invoice columns. Same denormalization
        pattern AP uses for DefaultPaymentMethod.

        Sort: within a customer group, rows are ordered by the active age-basis
        date (oldest first). A fixed ShipDate sort would put rows in the wrong
        operational order under DueDate mode (an invoice with later ship date
        but earlier due date should come first when reviewing past-due).
    */
    ;WITH BillRows AS
    (
        SELECT
            s.SalesId,
            s.ShipId                    AS PayeeId,        -- = ShipId per AR ownership rule
            pe.PayeeName,
            pe.TermId,                                      -- Payee's default term (not per-sale override)
            pe.LastPaymentDate,                             -- customer-level, denormalized per row
            pe.LastPaymentAmount,                           -- customer-level, denormalized per row
            s.SalesNumber,
            s.CustPONumber              AS PONumber,        -- customer's PO reference (free-form)
            s.ShipDate,
            s.DueDate,
            s.SalesTotal,
            s.AmountDue,
            DATEDIFF(DAY,
                CASE @AgeBasis
                    WHEN 'DueDate'     THEN ISNULL(s.DueDate, s.ShipDate)
                    WHEN 'InvoiceDate' THEN s.ShipDate
                END,
                @AsOfDate
            )                           AS AgeDays
        FROM dbo.Sales s
        INNER JOIN dbo.Payee pe ON pe.PayeeId = s.ShipId
        WHERE pe.PayeeType = 'C'
          AND s.AmountDue <> 0
          AND (@CustomerId IS NULL OR pe.PayeeId    = @CustomerId)
          AND (@TermId     IS NULL OR pe.TermId     = @TermId)
          AND (@SalesRepId IS NULL OR s.SalesRepId  = @SalesRepId)
    )
    SELECT
        b.SalesId,
        b.PayeeId,
        b.PayeeName         AS Customer,
        b.SalesNumber,
        b.PONumber,
        b.ShipDate,
        b.DueDate,
        t.TermName          AS Term,
        b.LastPaymentDate,
        b.LastPaymentAmount,
        b.SalesTotal        AS OriginalAmount,
        b.AmountDue         AS OpenBalance,
        b.AgeDays,

        -- Bucket label. Same column names work for both bases; only the
        -- first-numeric-bucket label differs ('1-30' for DueDate vs '0-30'
        -- for InvoiceDate). Frontend renders the label as-is.
        CASE
            WHEN @AgeBasis = 'DueDate' AND b.AgeDays < 0 THEN 'Current'
            WHEN b.AgeDays <= 30 THEN CASE @AgeBasis WHEN 'DueDate' THEN '1-30' ELSE '0-30' END
            WHEN b.AgeDays <= 60 THEN '31-60'
            WHEN b.AgeDays <= 90 THEN '61-90'
            ELSE                       'Over 90'
        END                 AS Bucket,

        -- Mirror columns: AmountDue lands in the row's own bucket, 0 in all
        -- others. Frontend SUMs each column for subtotals/grand totals.
        CASE WHEN @AgeBasis = 'DueDate' AND b.AgeDays < 0 THEN b.AmountDue ELSE 0 END AS BucketCurrent,
        CASE WHEN ((@AgeBasis = 'DueDate' AND b.AgeDays BETWEEN 0 AND 30)
                OR (@AgeBasis = 'InvoiceDate' AND b.AgeDays BETWEEN 0 AND 30))
             THEN b.AmountDue ELSE 0 END                  AS Bucket30,
        CASE WHEN b.AgeDays BETWEEN 31 AND 60 THEN b.AmountDue ELSE 0 END AS Bucket60,
        CASE WHEN b.AgeDays BETWEEN 61 AND 90 THEN b.AmountDue ELSE 0 END AS Bucket90,
        CASE WHEN b.AgeDays > 90               THEN b.AmountDue ELSE 0 END AS BucketOver90,

        CASE WHEN b.AmountDue < 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCredit
    FROM BillRows b
    LEFT JOIN dbo.Term t ON t.TermId = b.TermId
    ORDER BY
        b.PayeeName,
        -- Oldest first within customer — earliest source date = highest AgeDays.
        CASE @AgeBasis
            WHEN 'DueDate'     THEN ISNULL(b.DueDate, b.ShipDate)
            WHEN 'InvoiceDate' THEN b.ShipDate
        END;
END
GO
