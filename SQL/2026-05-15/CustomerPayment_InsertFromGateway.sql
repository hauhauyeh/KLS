-- =====================================================================
-- CustomerPayment_InsertFromGateway
--
-- 2026-05-15 change scope (Round 3 -- gateway hygiene for Round 1+2 work):
--
--   Round 1 (2026-05-11) added 4 new disposition parameters to
--   CustomerPayment_Insert (@PreviousExtraDisposition,
--   @NewExtraDisposition, @ExtraDispositionChanged,
--   @SelectedExtraDispositionAmount). They have defaults, but this gateway
--   wrapper was never updated to pass them. Phase 1B in CustomerPayment_Insert
--   reads disposition state from TempExtraPayment WHERE PayeeId = @PayeeId
--   AND CustomerPaymentId = @CustomerPaymentId. For gateway calls,
--   @CustomerPaymentId = 0, so any stale (PayeeId, 0) row in TempExtraPayment
--   leaks AsRefund / AsIncome / AsCredit / ExtraAmount into a fresh gateway
--   payment.
--
--   Round 2 (2026-05-13) added a defensive math check (THROW 50012) at
--   end of Phase 7 that compares @DirectDocumentApplied + @DirectCCFeeApplied
--   + (@ExtraAmount when AsIncome/AsRefund) - @CreditMemoUsed against
--   @PaymentAmount. When the leaked disposition values mismatch the
--   gateway's actual TempCustomerPayment apply rows, the check throws,
--   the transaction rolls back, and the customer-portal payment fails
--   to post (while potentially having already been debited at the
--   payment gateway).
--
--   This round (Round 3) closes the gap WITHOUT reverting Rounds 1 or 2:
--
--   (a) DELETE FROM TempExtraPayment upfront so no stale disposition row
--       leaks into Phase 1B of the inner CustomerPayment_Insert call.
--       Mirrors the existing TempCustomerPayment cleanup at the top
--       of this SP. Belt-and-braces WHERE: clears by EmpId (the user's
--       draft area) AND by (PayeeId, 0) (defensive against stale rows
--       left by other sessions for the same payee).
--
--   (b) Pass explicit values for the 4 disposition params on the
--       EXEC CustomerPayment_Insert call:
--           @PreviousExtraDisposition       = NULL
--           @NewExtraDisposition            = NULL
--           @ExtraDispositionChanged        = 0
--           @SelectedExtraDispositionAmount = 0
--       Self-documenting: a gateway payment has no extra disposition.
--       Future schema changes to CustomerPayment_Insert that adjust
--       these params' defaults won't silently change gateway behavior.
--
--   Live baseline at
--   SQL/2026-05-15/CustomerPayment_InsertFromGateway_live_baseline.sql.
-- =====================================================================

CREATE OR ALTER PROCEDURE [dbo].[CustomerPayment_InsertFromGateway]
    @PayeeId INT,
    @PaymentMethod NVARCHAR(50),
    @ReferenceId NVARCHAR(100),
    @PaymentAmount DECIMAL(18,2),
    @SalesIds NVARCHAR(MAX),
    @Gateway NVARCHAR(100),
    @CCFee DECIMAL(18,2),
    @CardType NVARCHAR(50),
    @Last4 NVARCHAR(50),
    @EmpId INT,
    @NewPaymentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PaymentDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @PaymentType NVARCHAR(50) = 'Actual Payment';

    DELETE FROM dbo.TempCustomerPayment
    WHERE EmpId = @EmpId;

    -- 2026-05-15 (Round 3): clear any stale extra-disposition row that could
    -- leak AsRefund / AsIncome / AsCredit / ExtraAmount into the inner
    -- CustomerPayment_Insert Phase 1B read. Belt-and-braces WHERE: by EmpId
    -- (this user's draft area) and by (PayeeId, 0) (defensive against rows
    -- left for the same payee by any other session). Mirrors the
    -- TempCustomerPayment cleanup immediately above.
    DELETE FROM dbo.TempExtraPayment
    WHERE EmpId = @EmpId
       OR (PayeeId = @PayeeId AND CustomerPaymentId = 0);

    DECLARE @SelectedSales TABLE
    (
        SalesId INT PRIMARY KEY
    );

    INSERT INTO @SelectedSales (SalesId)
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(@SalesIds, ',')
    WHERE TRY_CAST(LTRIM(RTRIM(value)) AS INT) IS NOT NULL;

    ;WITH AllDiscount AS
    (
        SELECT
            pd.SalesId,
            SUM(ISNULL(pd.PaymentDiscount, 0)) AS AllDiscountTaken
        FROM dbo.CustomerPaymentDetail pd
        GROUP BY pd.SalesId
    )
    INSERT INTO dbo.TempCustomerPayment
    (
        EmpId,
        PayeeId,
        CustomerPaymentId,
        SalesId,
        AmountDue,
        PaymentApplied,
        PaymentDiscount,
        ShortDiscount,
        OtherDiscount,
        IsCreditMemo,
        IsCCFee,
        IsApplied,
        SourceType,
        SourceId,
        IsSelected,
        DocNumber,
        DocDate,
        Description,
        BillName,
        OriginalAmount,
        OpenBalanceBefore,
        TermName,
        DiscountPercent,
        DiscountAlreadyTaken,
        DiscountDate,
        DueDays
    )
    SELECT
        @EmpId,
        @PayeeId,
        0,
        s.SalesId,
        s.AmountDue,
        s.AmountDue,          -- full apply for selected invoices
        0,
        0,
        0,
        CASE WHEN s.SalesTotal < 0 THEN 1 ELSE 0 END,
        0,
        1,
        CASE WHEN s.SalesTotal < 0 THEN 'CreditMemo' ELSE 'Invoice' END,
        s.SalesId,
        1,
        CAST(s.SalesNumber AS NVARCHAR(30)),
        s.ShipDate,
        ps.PayeeName,
        pb.PayeeName,
        s.SalesTotal,
        s.AmountDue,
        tm.TermName,
        ISNULL(s.DiscountPercent, ISNULL(tm.Discount, 0)),
        ISNULL(ad.AllDiscountTaken, 0),
        s.DiscountDate,
        ISNULL(tm.DueDays, 0)
    FROM dbo.Sales s
    INNER JOIN @SelectedSales ss
        ON ss.SalesId = s.SalesId
    INNER JOIN dbo.Payee ps
        ON ps.PayeeId = s.ShipId
    INNER JOIN dbo.Payee pb
        ON pb.PayeeId = s.BillId
    LEFT JOIN dbo.Term tm
        ON tm.TermId = s.TermId
    LEFT JOIN AllDiscount ad
        ON ad.SalesId = s.SalesId
    WHERE s.AmountDue <> 0
      AND s.BillId = @PayeeId;

    -- 2026-05-15 (Round 3): pass explicit values for the 4 disposition
    -- params added in Round 1 of CustomerPayment_Insert. A gateway payment
    -- has no extra disposition (no Income / Refund / CreditMemo on save);
    -- explicit zeros/nulls keep the inner SP's Phase 1B from defaulting
    -- through TempExtraPayment and self-document the intent.
    EXEC dbo.CustomerPayment_Insert
        @CustomerPaymentId             = 0,
        @PaymentType                   = @PaymentType,
        @PayeeId                       = @PayeeId,
        @PaymentDate                   = @PaymentDate,
        @PaymentMethod                 = @PaymentMethod,
        @FromAccountId                 = NULL,
        @ReferenceId                   = @ReferenceId,
        @PaymentAmount                 = @PaymentAmount,
        @Notes                         = @Gateway,
        @CCFee                         = @CCFee,
        @PreviousExtraDisposition      = NULL,
        @NewExtraDisposition           = NULL,
        @ExtraDispositionChanged       = 0,
        @SelectedExtraDispositionAmount = 0,
        @EmpId                         = @EmpId,
        @NewPaymentId                  = @NewPaymentId OUTPUT;

    UPDATE dbo.CustomerPayment
    SET CardType = @CardType,
        Last4 = @Last4
    WHERE CustomerPaymentId = @NewPaymentId;
END

