IF OBJECT_ID('dbo.CustomerPayment_InsertCCFee_prev', 'P') IS NOT NULL
    DROP PROCEDURE dbo.CustomerPayment_InsertCCFee_prev;

EXEC sp_rename 'dbo.CustomerPayment_InsertCCFee', 'CustomerPayment_InsertCCFee_prev';
GO

CREATE PROCEDURE [dbo].[CustomerPayment_InsertCCFee]

    @CustomerPaymentId INT,
    @PayeeId INT,
    @PaymentDate DATE,
    @CCFee DECIMAL(18,2),
    @EmpId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SalesId INT;
    DECLARE @AccountId INT;

    IF @CustomerPaymentId > 0
    BEGIN
        DELETE FROM dbo.TempCustomerPayment
        WHERE SalesId IN (
            SELECT SalesId
            FROM dbo.CustomerPaymentDetail
            WHERE CustomerPaymentId = @CustomerPaymentId
              AND IsCCFee = 1
        );

        DELETE FROM dbo.Sales
        WHERE SalesId IN (
            SELECT SalesId
            FROM dbo.CustomerPaymentDetail
            WHERE CustomerPaymentId = @CustomerPaymentId
              AND IsCCFee = 1
        );
    END;

    IF @CCFee <> 0
    BEGIN
        DELETE FROM dbo.TempSales
        WHERE EmpId = @EmpId
          AND PayeeId = @PayeeId;

        SELECT @AccountId = AccountId
        FROM dbo.Account
        WHERE AccountCode = '@ICCF';

        INSERT INTO dbo.TempSales
        (
            EmpId, SalesId, PayeeId, LineType, AccountId, OrdQty, ShipQty,
            BillQty, UnitPrice, Notes, FactorToBase
        )
        VALUES
        (
            @EmpId, 0, @PayeeId, 'A', @AccountId, 1, 1,
            1, @CCFee, 'CreditCardFee', 1
        );

        EXEC dbo.Sales_Insert
            @SalesId = 0,
            @PayeeId = @PayeeId,
            @ShipDate = @PaymentDate,
            @ShipRoute = NULL,
            @Instruction = 'CreditCardFee',
            @StageId = 4,
            @EmpId = @EmpId,
            @NewSalesId = @SalesId OUTPUT,
            @DocType = 'SO',
            @ParentSalesNumber = NULL,
            @AllowNoParentOverride = 0;

        INSERT INTO dbo.TempCustomerPayment
        (
            EmpId, PayeeId, CustomerPaymentId, SalesId, AmountDue, PaymentApplied,
            PaymentDiscount, ShortDiscount, OtherDiscount, IsCCFee, IsApplied,
            SourceType, SourceId, IsSelected, DocNumber, DocDate, Description, BillName,
            OriginalAmount, OpenBalanceBefore, TermName, DiscountPercent, DiscountAlreadyTaken,
            DiscountDate, DueDays
        )
        SELECT
            @EmpId,
            @PayeeId,
            @CustomerPaymentId,
            s.SalesId,
            s.AmountDue,
            s.AmountDue,
            0,
            0,
            0,
            1,
            1,
            'CCFee',
            s.SalesId,
            1,
            CAST(s.SalesNumber AS NVARCHAR(30)),
            s.ShipDate,
            'Credit Card Fee',
            NULL,
            s.SalesTotal,
            s.AmountDue,
            NULL,
            0,
            0,
            NULL,
            0
        FROM dbo.Sales s
        WHERE s.SalesId = @SalesId;
    END;
END
GO
