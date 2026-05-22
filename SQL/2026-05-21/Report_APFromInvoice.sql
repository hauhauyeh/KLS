SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- First round for THIS SP — snapshot existing as _prev (idempotent).
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Report_APFromInvoice')
   AND NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Report_APFromInvoice_prev')
    EXEC sp_rename 'Report_APFromInvoice', 'Report_APFromInvoice_prev';
GO

DROP PROCEDURE IF EXISTS [dbo].[Report_APFromInvoice];
GO

CREATE PROCEDURE [dbo].[Report_APFromInvoice]
    @Term     NVARCHAR(50),
    @Sortby   NVARCHAR(50),
    @Filterby NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    /*
      Invoice-date AP aging report.

      Reads buckets from View_Vendor (single source of truth, real-time after
      this round's rewrite). The Frankenstein "DueDays > 0 AND < 30" branch is
      gone — View_Vendor.InvoiceAge30 is already the 0-30 since-invoice bucket
      for every vendor.

      Inv0 column dropped (Step 7 frontend cleanup) — Frankenstein split is
      gone; InvoiceAge30 is the full 0-30 bucket for every vendor.
    */

    SELECT
        vv.PayeeId,
        vv.PayeeName,
        p.PhoneDesc1,
        p.Phone1,

        vv.InvoiceAge60     AS Invoice60,
        vv.InvoiceAge90     AS Invoice90,
        vv.InvoiceAgeOver90 AS InvoiceOver90,
        vv.PayeeTotalDue,

        p.TermId,
        NULL                AS Region,    -- preserved from baseline (Vendor doesn't carry Region)
        t.DueDays,

        vv.InvoiceAge30     AS Inv30

    FROM dbo.View_Vendor vv
    INNER JOIN dbo.Payee  p ON p.PayeeId  = vv.PayeeId
    LEFT  JOIN dbo.Term   t ON t.TermId   = p.TermId

    WHERE p.PayeeType = 'V'
      AND (@Term IS NULL OR p.TermId = @Term)
      AND
      (
            (@Filterby = '30' AND vv.InvoiceAge30     <> 0) OR
            (@Filterby = '60' AND vv.InvoiceAge60     <> 0) OR
            (@Filterby = '90' AND vv.InvoiceAge90     <> 0) OR
            (@Filterby = '91' AND vv.InvoiceAgeOver90 <> 0) OR
            (@Filterby IS NULL AND vv.PayeeTotalDue   <> 0)
      )

    ORDER BY
        CASE WHEN @Sortby = 'Customer' THEN vv.PayeeName END,
        CASE WHEN @Sortby = 'Total'    THEN vv.PayeeTotalDue END DESC,
        vv.PayeeName;  -- default fallback
END
GO
