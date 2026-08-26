CREATE OR ALTER PROCEDURE [dbo].[CustomerPayment_ReserveCreditMemoRefund]
    @PayeeId INT,
    @SalesIds NVARCHAR(MAX),
    @PaymentDate DATE,
    @Notes NVARCHAR(255) = NULL,
    @EmpId INT,
    @NewPaymentId INT OUTPUT,
    @NewPaymentDetailId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @PaymentNumber INT;
    DECLARE @RefundAmount DECIMAL(18,2);
    DECLARE @TxId BIGINT;
    DECLARE @SourceDocOrder INT;
    DECLARE @AccountId INT;
    DECLARE @Amount DECIMAL(18,2);
    DECLARE @CrDeAmount DECIMAL(18,2);

    DECLARE @AcctTable TABLE
    (
        AccountCode NVARCHAR(50) PRIMARY KEY,
        AccountId INT NULL
    );

    INSERT INTO @AcctTable(AccountCode) VALUES('@AR');
    INSERT INTO @AcctTable(AccountCode) VALUES('@CRP');

    UPDATE t
    SET t.AccountId = a.AccountId
    FROM @AcctTable AS t
    INNER JOIN dbo.Account AS a ON a.AccountCode = t.AccountCode;

    IF EXISTS (SELECT 1 FROM @AcctTable WHERE AccountId IS NULL)
        THROW 50110, 'Required refund reserve accounts are not configured.', 1;

    IF ISNULL(@PayeeId, 0) <= 0
        THROW 50111, 'Customer is required.', 1;

    IF @PaymentDate IS NULL
        THROW 50112, 'Refund reserve date is required.', 1;

    IF NULLIF(LTRIM(RTRIM(ISNULL(@SalesIds, ''))), '') IS NULL
        THROW 50113, 'Select at least one credit memo to refund.', 1;

    CREATE TABLE #RequestedSales
    (
        SalesId INT NOT NULL PRIMARY KEY
    );

    INSERT INTO #RequestedSales(SalesId)
    SELECT DISTINCT TRY_CONVERT(INT, LTRIM(RTRIM(value)))
    FROM STRING_SPLIT(@SalesIds, ',')
    WHERE NULLIF(LTRIM(RTRIM(value)), '') IS NOT NULL
      AND TRY_CONVERT(INT, LTRIM(RTRIM(value))) > 0;

    IF EXISTS
    (
        SELECT 1
        FROM STRING_SPLIT(@SalesIds, ',')
        WHERE NULLIF(LTRIM(RTRIM(value)), '') IS NOT NULL
          AND (TRY_CONVERT(INT, LTRIM(RTRIM(value))) IS NULL OR TRY_CONVERT(INT, LTRIM(RTRIM(value))) <= 0)
    )
        THROW 50114, 'SalesIds contains an invalid id.', 1;

    IF NOT EXISTS (SELECT 1 FROM #RequestedSales)
        THROW 50115, 'Select at least one credit memo to refund.', 1;

    CREATE TABLE #SelectedCreditMemo
    (
        SalesId INT NOT NULL PRIMARY KEY,
        SalesNumber INT NOT NULL,
        AmountDue DECIMAL(18,2) NOT NULL
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO #SelectedCreditMemo(SalesId, SalesNumber, AmountDue)
        SELECT
            s.SalesId,
            s.SalesNumber,
            ISNULL(s.AmountDue, 0)
        FROM dbo.Sales AS s WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN #RequestedSales AS r ON r.SalesId = s.SalesId;

        IF (SELECT COUNT(*) FROM #SelectedCreditMemo) <> (SELECT COUNT(*) FROM #RequestedSales)
            THROW 50116, 'One or more selected credit memos were not found.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Sales AS s
            INNER JOIN #RequestedSales AS r ON r.SalesId = s.SalesId
            WHERE ISNULL(s.BillId, 0) <> @PayeeId
              AND ISNULL(s.ShipId, 0) <> @PayeeId
        )
            THROW 50117, 'Selected credit memos do not belong to this customer.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Sales AS s
            INNER JOIN #RequestedSales AS r ON r.SalesId = s.SalesId
            WHERE ISNULL(s.DocType, '') <> 'CM'
              OR ISNULL(s.SalesTotal, 0) >= 0
              OR ISNULL(s.AmountDue, 0) >= 0
        )
            THROW 50118, 'Only open sales credit memos can be reserved for refund.', 1;

        SET @RefundAmount = (
            SELECT SUM(ABS(AmountDue))
            FROM #SelectedCreditMemo
        );

        IF ISNULL(@RefundAmount, 0) <= 0
            THROW 50119, 'Refund amount must be greater than zero.', 1;

        SET @PaymentNumber = NEXT VALUE FOR dbo.Seq_CustomerPaymentNumber;

        INSERT INTO dbo.CustomerPayment
        (
            PaymentNumber, PaymentType, PayeeId, PaymentDate, PaymentMethod, FromAccountId,
            ReferenceId, PaymentAmount, Notes, PaymentApplied, UnappliedAmount, IsBadDebt,
            CreatedAt, UpdatedAt
        )
        VALUES
        (
            @PaymentNumber, 'Credit Memo Refund Reserve', @PayeeId, @PaymentDate, NULL, NULL,
            NULL, 0, @Notes, 0, 0, 0,
            GETUTCDATE(), NULL
        );

        SET @NewPaymentId = SCOPE_IDENTITY();

        INSERT INTO dbo.CustomerPaymentDetail
        (
            CustomerPaymentId, SalesId, PaymentApplied, PaymentDiscount, ShortDiscount,
            OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber,
            DetailRole, SourceCustomerPaymentId, SourceSalesId
        )
        SELECT
            @NewPaymentId,
            SalesId,
            AmountDue,
            0,
            0,
            0,
            1,
            0,
            NULL,
            'CreditMemo',
            NULL,
            SalesId
        FROM #SelectedCreditMemo
        ORDER BY SalesNumber;

        EXEC dbo.CustomerPayment_UpdateSales @NewPaymentId, 0;

        INSERT INTO dbo.CustomerPaymentDetail
        (
            CustomerPaymentId, SalesId, PaymentApplied, PaymentDiscount, ShortDiscount,
            OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber,
            DetailRole, SourceCustomerPaymentId, SourceSalesId
        )
        VALUES
        (
            @NewPaymentId,
            0,
            @RefundAmount,
            0,
            0,
            0,
            0,
            0,
            @PaymentNumber,
            'AsRefund',
            @NewPaymentId,
            NULL
        );

        SET @NewPaymentDetailId = SCOPE_IDENTITY();

        EXEC dbo.Get_SourceDocOrder 'Customer Payment', @SourceDocOrder OUTPUT;

        INSERT INTO dbo.TransactionJournal
        (
            TxDate, TxTime, SourceDocOrder, SourceDocType, SourceDocNumber, Notes
        )
        VALUES
        (
            @PaymentDate, GETUTCDATE(), @SourceDocOrder, 'Customer Payment', @PaymentNumber, @Notes
        );

        SET @TxId = SCOPE_IDENTITY();

        SET @Amount = @RefundAmount;
        SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@AR';
        EXEC dbo.Fn_Adjust_CrDeAmount @AccountId, @Amount, @CrDeAmount OUTPUT;

        INSERT INTO dbo.TransactionJournalDetail(TxId, AccountId, PayeeId, Amount, CrDeAmount)
        VALUES(@TxId, @AccountId, @PayeeId, @Amount, @CrDeAmount);

        SET @Amount = @RefundAmount;
        SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@CRP';
        EXEC dbo.Fn_Adjust_CrDeAmount @AccountId, @Amount, @CrDeAmount OUTPUT;

        INSERT INTO dbo.TransactionJournalDetail(TxId, AccountId, PayeeId, Amount, CrDeAmount)
        VALUES(@TxId, @AccountId, @PayeeId, @Amount, @CrDeAmount);

        IF EXISTS
        (
            SELECT 1
            FROM dbo.TransactionJournalDetail
            WHERE TxId = @TxId
            GROUP BY TxId
            HAVING ROUND(SUM(ISNULL(CrDeAmount, 0)), 2) <> 0
        )
            THROW 50120, 'Refund reserve journal is out of balance.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END
GO
