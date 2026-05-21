SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- _prev already exists from a prior round → DROP + CREATE (do not re-rename).
DROP PROCEDURE IF EXISTS [dbo].[Report_ARFromInvoice];
GO

CREATE PROCEDURE [dbo].[Report_ARFromInvoice]
    @Term     NVARCHAR(50),
    @Sortby   NVARCHAR(50),
    @Filterby NVARCHAR(50),
    @SalesRep INT
AS
BEGIN
    SET NOCOUNT ON;

    /*
      Invoice-date AR aging report.

      Reads buckets from View_Customer (single source of truth) instead of cached
      Payee.* fields. The Frankenstein "DueDays > 0 AND < 30" branch is gone —
      View_Customer.InvoiceAge30 is already the 0-30 since-shipped bucket for
      every customer, regardless of term length.

      Extra columns (PhoneDesc1/Phone1, OwedSince, UnAppliedAmt) come from inline
      sub-selects because View_Customer doesn't surface them.

      Inv0 is returned as 0 for legacy frontend shape compatibility (the report
      component still has IsFirstColumn logic that conditionally renders a split
      column). Inv30 carries the full new 0-30 bucket. The frontend can be
      simplified later to drop Inv0 + IsFirstColumn entirely.
    */

    SELECT
        c.Region,
        vc.PayeeId,
        vc.PayeeName,
        p.PhoneDesc1,
        p.Phone1,

        vc.InvoiceAge60     AS Invoice60,
        vc.InvoiceAge90     AS Invoice90,
        vc.InvoiceAgeOver90 AS InvoiceOver90,
        vc.PayeeTotalDue,

        vc.LastPaymentDate    AS LastPmtDate,
        vc.LastPaymentAmount  AS LastPmtAmt,
        owed.OwedSince,
        unapp.UnAppliedAmt,

        vc.TermId,
        t.DueDays,

        CAST(0 AS DECIMAL(18,2)) AS Inv0,   -- legacy: Frankenstein split removed
        vc.InvoiceAge30          AS Inv30

    FROM dbo.View_Customer vc
    INNER JOIN dbo.Payee    p ON p.PayeeId = vc.PayeeId
    INNER JOIN dbo.Customer c ON c.PayeeId = vc.PayeeId
    LEFT  JOIN dbo.Term     t ON t.TermId  = vc.TermId

    OUTER APPLY
    (
        SELECT MIN(CASE WHEN s.AmountDue > 0 THEN s.ShipDate END) AS OwedSince
        FROM dbo.Sales s
        WHERE s.ShipId = vc.PayeeId
    ) AS owed

    OUTER APPLY
    (
        SELECT SUM(CASE WHEN cp.UnappliedAmount <> 0 THEN cp.UnappliedAmount ELSE 0 END) AS UnAppliedAmt
        FROM dbo.CustomerPayment cp
        WHERE cp.PayeeId = vc.PayeeId
    ) AS unapp

    WHERE p.PayeeType = 'c'
      AND (@Term     IS NULL OR vc.TermId       = @Term)
      AND (@SalesRep IS NULL OR c.SalesRepId    = @SalesRep)
      AND
      (
            (@Filterby = '30' AND vc.InvoiceAge30     <> 0) OR
            (@Filterby = '60' AND vc.InvoiceAge60     <> 0) OR
            (@Filterby = '90' AND vc.InvoiceAge90     <> 0) OR
            (@Filterby = '91' AND vc.InvoiceAgeOver90 <> 0) OR
            (@Filterby IS NULL AND vc.PayeeTotalDue   <> 0)
      )

    ORDER BY
        CASE WHEN @Sortby = 'Customer' THEN vc.PayeeName END,
        CASE WHEN @Sortby = 'Total'    THEN vc.PayeeTotalDue END DESC,
        vc.PayeeName;  -- default fallback
END
GO
