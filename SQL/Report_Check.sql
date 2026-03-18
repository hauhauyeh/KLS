-- Deploy: Create Report_Check SP
-- Migrated from KLS_New with updated column/table names

CREATE PROCEDURE [dbo].[Report_Check]
    @Filterby NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CAST(ROW_NUMBER() OVER (ORDER BY v.ReferenceId) AS INT) AS Rn,
        v.VendorPaymentId,
        v.PaymentDate AS PmtDate,
        v.ReferenceId AS PmtRefNum,
        v.PaymentAmount AS PmtAmount,
        p.PayeeName,
        v.MailDate,
        v.BankDate,
        ac.AccountName AS BankName,
        v.IsVoid
    FROM VendorPayment AS v
    INNER JOIN Payee AS p ON v.PayeeId = p.PayeeId
    LEFT JOIN Account AS ac ON ac.AccountId = v.FromAccountId
    WHERE v.PaymentMethod IN ('CHECK', 'HANDWRITE CHECK')
      AND (v.BankDate IS NULL OR v.MailDate IS NULL)
      AND v.IsVoid = 0
      AND (@Filterby IS NULL OR @Filterby = 'vendor' AND p.PayeeType = 'V' OR @Filterby = 'all')
    ORDER BY v.ReferenceId;
END
