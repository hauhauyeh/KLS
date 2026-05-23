/*
    CustomerPayment_InsertFromGateway.sql
    2026-05-22

    Two changes from baseline:

    1. New @UserNotes parameter: optional user-entered note from the charge
       dialog. Composed with the auto-generated Gateway label into a single
       Notes string passed to CustomerPayment_Insert:
           "MX Merchant HY"                       (no user note)
           "MX Merchant HY -- check img #1 of 2"  (with user note)

    2. Disposition derivation when @SalesIds is empty: the frontend signals
       "Charge now, Apply later" by clearing SalesIds. The SP picks that up
       and plumbs @NewExtraDisposition='Credit' through to
       CustomerPayment_Insert, which then carves out the over-application
       check at line 1238 of that SP (the gap that previously caused the
       silent over-application throw on diverged amounts).

    CustomerPayment_Insert itself is NOT modified. Its existing carve-out at
    line 351 (IF @NewExtraDisposition = 'Credit' SET @AsCredit = 1) does the
    right thing once disposition is plumbed.

    Deploy:
        _prev already exists from a prior round, so this is DROP + CREATE only.
*/

-- SET options must match the live SP's compile-time options, otherwise
-- DELETE/UPDATE statements that touch filtered indexes throw at runtime
-- (Msg 1934: "DELETE failed because the following SET options have incorrect
-- settings: 'QUOTED_IDENTIFIER'").
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

DROP PROCEDURE IF EXISTS [dbo].[CustomerPayment_InsertFromGateway];
GO

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
    @UserNotes NVARCHAR(MAX) = NULL,
    @NewPaymentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PaymentDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @PaymentType NVARCHAR(50) = 'Actual Payment';

    -- Compose final Notes: gateway label + optional user note.
    DECLARE @ComposedNotes NVARCHAR(MAX) = @Gateway;
    IF NULLIF(LTRIM(RTRIM(@UserNotes)), '') IS NOT NULL
        SET @ComposedNotes = ISNULL(@ComposedNotes, '') + ' -- ' + @UserNotes;

    -- Disposition for "Charge now, Apply later" path. The frontend signals
    -- this by sending empty SalesIds (no invoices to apply to). The SP plumbs
    -- 'Credit' disposition into CustomerPayment_Insert, which carves out the
    -- over-application invariant and lands the full payment as unapplied
    -- credit on the payee.
    DECLARE @NewExtraDisposition NVARCHAR(50) = NULL;
    DECLARE @ExtraDispositionChanged BIT = NULL;
    DECLARE @SelectedExtraDispositionAmount DECIMAL(18,2) = NULL;

    IF ISNULL(LTRIM(RTRIM(@SalesIds)), '') = ''
    BEGIN
        SET @NewExtraDisposition = 'Credit';
        SET @ExtraDispositionChanged = 1;
        SET @SelectedExtraDispositionAmount = @PaymentAmount;
    END;

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
        @Notes = @ComposedNotes,
        @CCFee = @CCFee,
        @PreviousExtraDisposition = NULL,
        @NewExtraDisposition = @NewExtraDisposition,
        @ExtraDispositionChanged = @ExtraDispositionChanged,
        @SelectedExtraDispositionAmount = @SelectedExtraDispositionAmount,
        @EmpId = @EmpId,
        @NewPaymentId = @NewPaymentId OUTPUT;

    UPDATE dbo.CustomerPayment
    SET CardType = @CardType,
        Last4 = @Last4
    WHERE CustomerPaymentId = @NewPaymentId;
END
GO
