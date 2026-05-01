-- Deploy: Create Report_CheckToBePrinted SP
-- Migrated from KLS_New with updated column/table names

CREATE PROCEDURE [dbo].[Report_CheckToBePrinted]
    @PmtMethod NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @15days DATE = DATEADD(DAY, 15, GETDATE());

    SELECT
        CAST(ROW_NUMBER() OVER (ORDER BY pr.DueDate, py.PayeeName) AS INT) AS Rn,
        pr.PurchaseId,
        pr.ArrivalDate,
        pr.VendorDocNumber AS VendorDocNum,
        pr.AmountDue,
        t.TermName AS PmtTerm,
        pr.DueDate,
        py.PayeeName,
        v.DefaultPaymentMethod AS VendorPmtMethod
    FROM Purchase AS pr
    INNER JOIN Payee AS py ON pr.PayeeId = py.PayeeId
    LEFT JOIN Vendor AS v ON v.PayeeId = pr.PayeeId
    LEFT JOIN Term AS t ON py.TermId = t.TermId
    WHERE pr.AmountDue > 0
      AND pr.DueDate <= @15days
      AND (
            (@PmtMethod = 'not assign' AND v.DefaultPaymentMethod IS NULL) OR
            (@PmtMethod IS NOT NULL AND @PmtMethod <> 'not assign' AND v.DefaultPaymentMethod = @PmtMethod) OR
            @PmtMethod IS NULL
          )
    ORDER BY pr.DueDate, py.PayeeName;
END
