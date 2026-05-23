/*
    CustomerPayment_InsertFromGateway_live_baseline.sql
    Captured 2026-05-22 from prod (INTEL-2023\SQLEXPRESS, KLS_2026).

    Frozen snapshot of the currently-deployed CustomerPayment_InsertFromGateway
    SP as of the start of the ACH Charge & Apply / Charge now, Apply later
    fix round.

    Note: CustomerPayment_InsertFromGateway_prev already exists on prod from
    a prior round, so the deploy script does DROP + CREATE only (no rename).

    DO NOT EDIT — baseline only.
*/

CREATE PROCEDURE [dbo].[CustomerPayment_InsertFromGateway]
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

    EXEC dbo.CustomerPayment_Insert
        @CustomerPaymentId = 0,
        @PaymentType = @PaymentType,
        @PayeeId = @PayeeId,
        @PaymentDate = @PaymentDate,
        @PaymentMethod = @PaymentMethod,
        @FromAccountId = NULL,
        @ReferenceId = @ReferenceId,
        @PaymentAmount = @PaymentAmount,
        @Notes = @Gateway,
        @CCFee = @CCFee,
        @PreviousExtraDisposition = null,
        @NewExtraDisposition = null,
        @ExtraDispositionChanged = null,
        @SelectedExtraDispositionAmount = null,
        @EmpId = @EmpId,
        @NewPaymentId = @NewPaymentId OUTPUT;

    UPDATE dbo.CustomerPayment
    SET CardType = @CardType,
        Last4 = @Last4
    WHERE CustomerPaymentId = @NewPaymentId;
END
