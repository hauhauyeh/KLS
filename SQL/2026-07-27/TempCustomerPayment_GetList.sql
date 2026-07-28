-- 2026-07-27 SalesDocNumber Slice 10B: expose SalesDocNumber for temp customer payment cart display.
-- Baseline: live dbo.TempCustomerPayment_GetList after 2026-04-30 temp-payment rework.
CREATE OR ALTER PROCEDURE [dbo].[TempCustomerPayment_GetList]
    @EmpId INT,
    @PayeeId INT,
    @CustomerPaymentId INT,
    @Id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        t.TempCPId,
        t.EmpId,
        t.PayeeId,
        t.CustomerPaymentId,
        t.SalesId,
        t.AmountDue,
        t.PaymentApplied,
        t.DiscountApplied,
        t.PaymentDiscount,
        t.ShortDiscount,
        t.OtherDiscount,
        t.IsApplied,
        t.IsCreditMemo,
        t.IsCCFee,
        CASE WHEN t.SourceType = 'UnappliedPayment' THEN 0
             ELSE TRY_CAST(ISNULL(t.DocNumber, CAST(s.SalesNumber AS NVARCHAR(30))) AS INT)
        END AS SalesNumber,
        s.SalesDocNumber,
        ISNULL(t.DocDate, s.ShipDate) AS ShipDate,
        ISNULL(t.OriginalAmount, s.SalesTotal) AS SalesTotal,
        ISNULL(t.Description, ps.PayeeName) AS ShipName,
        ISNULL(t.BillName, pb.PayeeName) AS BillName,
        t.SourceType,
        t.SourceId,
        t.IsSelected,
        t.DocNumber,
        t.DocDate,
        t.Description,
        t.OriginalAmount,
        t.OpenBalanceBefore,
        t.TermName,
        t.DiscountPercent,
        t.DiscountAlreadyTaken,
        t.DiscountDate,
        t.DueDays
    FROM dbo.TempCustomerPayment t
    LEFT JOIN dbo.Sales s ON t.SalesId = s.SalesId
    LEFT JOIN dbo.Payee ps ON ps.PayeeId = s.ShipId
    LEFT JOIN dbo.Payee pb ON pb.PayeeId = s.BillId
    WHERE t.EmpId = @EmpId
      AND t.PayeeId = @PayeeId
      AND t.CustomerPaymentId = @CustomerPaymentId
      AND (@Id IS NULL OR t.TempCPId = @Id)
    ORDER BY
        CASE t.SourceType
            WHEN 'UnappliedPayment' THEN 0
            WHEN 'CreditMemo' THEN 1
            WHEN 'Invoice' THEN 2
            WHEN 'DebitMemo' THEN 3
            WHEN 'CCFee' THEN 4
            ELSE 5
        END,
        ISNULL(t.DocDate, s.ShipDate),
        t.TempCPId;
END
