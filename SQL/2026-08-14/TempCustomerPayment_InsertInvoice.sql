SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-08-14 CUSTOMER-PAYMENT-OB-NO-JOURNAL: opening balance AR rows (Sales.DocType='OB')
-- are payment-eligible even though they do not have a normal Sales journal.
CREATE OR ALTER PROCEDURE [dbo].[TempCustomerPayment_InsertInvoice] -- EXEC dbo.TempCustomerPayment_InsertInvoice @EmpId=1,@CustomerPaymentId=0,@SalesNumber=100000,@TempId=0

    @EmpId INT,
    @CustomerPaymentId INT,
    @SalesNumber INT,
    @TempId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SalesId INT;
    DECLARE @AmountDue DECIMAL(18,2);
    DECLARE @SalesTotal DECIMAL(18,2);
    DECLARE @ShipId INT;
    DECLARE @BillId INT;
    DECLARE @ShipDate DATE;
    DECLARE @ShipName NVARCHAR(200);
    DECLARE @BillName NVARCHAR(200);
    DECLARE @TermName NVARCHAR(50);
    DECLARE @DiscountPercent DECIMAL(18,4);
    DECLARE @DiscountAlreadyTaken DECIMAL(18,2);
    DECLARE @DiscountDate DATE;
    DECLARE @DueDays INT;
    DECLARE @Error NVARCHAR(255);
    DECLARE @Exists INT;
    DECLARE @SourceType NVARCHAR(20);
    DECLARE @DocType NVARCHAR(20);

    SELECT TOP (1) @SalesId = s.SalesId
    FROM dbo.Sales s
    WHERE s.SalesNumber = @SalesNumber;

    IF @SalesId IS NULL
    BEGIN
        SET @Error = 'Please enter valid invoice#';
        RAISERROR(@Error, 16, 1);
        RETURN;
    END;

    SELECT @Exists = COUNT(SalesId)
    FROM dbo.TempCustomerPayment
    WHERE EmpId = @EmpId
      AND CustomerPaymentId = @CustomerPaymentId
      AND SalesId = @SalesId;

    IF @Exists > 0
    BEGIN
        SET @Error = 'Invoice already exists in the list.';
        RAISERROR(@Error, 16, 1);
        RETURN;
    END;

    SELECT
        @AmountDue = ISNULL(s.AmountDue, 0),
        @SalesTotal = ISNULL(s.SalesTotal, 0),
        @ShipId = s.ShipId,
        @BillId = s.BillId,
        @ShipDate = s.ShipDate,
        @ShipName = ps.PayeeName,
        @BillName = pb.PayeeName,
        @TermName = tm.TermName,
        @DiscountPercent = ISNULL(s.DiscountPercent, ISNULL(tm.Discount, 0)),
        @DiscountDate = s.DiscountDate,
        @DueDays = ISNULL(tm.DueDays, 0),
        @DocType = s.DocType
    FROM dbo.Sales s
    INNER JOIN dbo.Payee ps ON ps.PayeeId = s.ShipId
    INNER JOIN dbo.Payee pb ON pb.PayeeId = s.BillId
    LEFT JOIN dbo.Term tm ON tm.TermId = s.TermId
    WHERE s.SalesId = @SalesId;

    IF @SalesTotal > 0
       AND ISNULL(@DocType, '') <> 'OB'
       AND NOT EXISTS (
            SELECT 1
            FROM dbo.TransactionJournal AS tj
            WHERE tj.SourceDocType = 'Sales'
              AND tj.SourceDocNumber = @SalesNumber
       )
    BEGIN
        SET @Error = 'Invoice is not posted to AR yet.';
        RAISERROR(@Error, 16, 1);
        RETURN;
    END;

    SELECT
        @DiscountAlreadyTaken = ISNULL(SUM(ISNULL(pd.PaymentDiscount, 0)), 0)
    FROM dbo.CustomerPaymentDetail pd
    WHERE pd.SalesId = @SalesId;

    SET @SourceType = CASE WHEN @SalesTotal < 0 THEN 'CreditMemo' ELSE 'Invoice' END;

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
        IsApplied,
        IsCreditMemo,
        IsCCFee,
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
    VALUES
    (
        @EmpId,
        @ShipId,
        @CustomerPaymentId,
        @SalesId,
        @AmountDue,
        @AmountDue,
        0,
        0,
        0,
        1,
        CASE WHEN @SalesTotal < 0 THEN 1 ELSE 0 END,
        0,
        @SourceType,
        @SalesId,
        1,
        CAST(@SalesNumber AS NVARCHAR(30)),
        @ShipDate,
        @ShipName,
        @BillName,
        @SalesTotal,
        @AmountDue,
        @TermName,
        ISNULL(@DiscountPercent, 0),
        ISNULL(@DiscountAlreadyTaken, 0),
        @DiscountDate,
        ISNULL(@DueDays, 0)
    );

    SELECT @TempId = SCOPE_IDENTITY();
END

