SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[CustomerPayment_Insert]

    @CustomerPaymentId INT,
    @PaymentType NVARCHAR(100),
    @PayeeId INT,
    @PaymentDate DATE,
    @PaymentMethod NVARCHAR(50),
    @FromAccountId INT,
    @ReferenceId NVARCHAR(100),
    @PaymentAmount DECIMAL(18,2),
    @Notes NVARCHAR(255),
    @CCFee DECIMAL(18,2),
    @EmpId INT,
    @NewPaymentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

    /*
        Live baseline captured on 2026-04-29 before the next CCFee header-only fix.

        Purpose of this file:
        - preserve the exact live rollback target
        - allow direct live restore without reconstructing from memory
        - keep SQL rollback material next to the working procedure

        This baseline is intentionally a snapshot, not the working change file.
    */

    DECLARE @TxId BIGINT;
    DECLARE @CrDeAmount DECIMAL(18,2) = 0;
    DECLARE @AccountId INT;
    DECLARE @SourceDocOrder INT;
    DECLARE @SourceDocType NVARCHAR(100);

    DECLARE @IsBadDebt BIT = 0;
    DECLARE @AR DECIMAL(18,2);
    DECLARE @Amount DECIMAL(18,2);

    DECLARE @IsEdit BIT = 0;
    DECLARE @OldId INT = @CustomerPaymentId;
    DECLARE @PaymentNumber INT = 0;
    DECLARE @CreatedAt DATETIME = GETUTCDATE();
    DECLARE @UpdatedAt DATETIME;

    DECLARE @CashApplied DECIMAL(18,2) = 0;
    DECLARE @TotalDiscountApplied DECIMAL(18,2) = 0;
    DECLARE @CreditMemoUsed DECIMAL(18,2) = 0;
    DECLARE @PriorUnappliedUsed DECIMAL(18,2) = 0;

    DECLARE @AsCredit BIT = 0;
    DECLARE @AsIncome BIT = 0;
    DECLARE @AsRefund BIT = 0;
    DECLARE @ExtraAmount DECIMAL(18,2) = 0;
    DECLARE @SourceUseAsIncome DECIMAL(18,2) = 0;
    DECLARE @SourceUseRefundSelf DECIMAL(18,2) = 0;
    DECLARE @PrevAsIncome DECIMAL(18,2) = 0;
    DECLARE @PrevRefund DECIMAL(18,2) = 0;

    CREATE TABLE #AffectedSourcePayment
    (
        PaymentNumber INT PRIMARY KEY
    );

    DECLARE @AcctTable AS TABLE(
        Id INT IDENTITY(1,1),
        AccountCode NVARCHAR(50),
        AccountId INT
    );

    INSERT INTO @AcctTable(AccountCode) VALUES('@AR');
    INSERT INTO @AcctTable(AccountCode) VALUES('@UF');
    INSERT INTO @AcctTable(AccountCode) VALUES('@IDG');
    INSERT INTO @AcctTable(AccountCode) VALUES('@IOT');
    INSERT INTO @AcctTable(AccountCode) VALUES('@CRP');
    INSERT INTO @AcctTable(AccountCode) VALUES('@EBAD');
    INSERT INTO @AcctTable(AccountCode) VALUES('@INV');

    UPDATE t
    SET t.AccountId = a.AccountId
    FROM @AcctTable AS t
    INNER JOIN dbo.Account AS a ON t.AccountCode = a.AccountCode;

    IF @CustomerPaymentId > 0
    BEGIN
        INSERT INTO #AffectedSourcePayment(PaymentNumber)
        SELECT DISTINCT SourcePaymentNumber
        FROM dbo.CustomerPaymentDetail
        WHERE CustomerPaymentId = @CustomerPaymentId
          AND SourcePaymentNumber IS NOT NULL;

        DELETE FROM dbo.TempCustomerPayment
        WHERE SalesId IN (
            SELECT SalesId
            FROM dbo.CustomerPaymentDetail
            WHERE CustomerPaymentId = @CustomerPaymentId
              AND IsCCFee = 1
        );
    END;

    IF @PaymentType = 'Bad Debt'
    BEGIN
        SET @IsBadDebt = 1;
        SET @PaymentMethod = NULL;
    END
    ELSE IF @PaymentType = 'Credit Apply'
        SET @PaymentMethod = NULL;

    IF @PaymentType = 'Customer Refund'
    BEGIN
        SET @SourceDocType = 'Customer Refund';
        EXEC dbo.Get_SourceDocOrder @SourceDocType, @SourceDocOrder OUTPUT;
    END
    ELSE
    BEGIN
        SET @SourceDocType = 'Customer Payment';
        EXEC dbo.Get_SourceDocOrder @SourceDocType, @SourceDocOrder OUTPUT;
        SET @FromAccountId = NULL;
    END;

    SELECT
        @AsCredit = AsCredit,
        @AsIncome = AsIncome,
        @AsRefund = AsRefund,
        @ExtraAmount = ExtraAmount
    FROM dbo.TempExtraPayment
    WHERE PayeeId = @PayeeId
      AND CustomerPaymentId = @CustomerPaymentId;

    IF (@AsCredit = 1)
        UPDATE dbo.TempCustomerPayment
        SET PaymentApplied = OpenBalanceBefore - DiscountApplied
        WHERE EmpId = @EmpId
          AND PayeeId = @PayeeId
          AND CustomerPaymentId = @CustomerPaymentId
          AND ISNULL(IsSelected, IsApplied) = 1
          AND SourceType IN ('Invoice', 'DebitMemo')
          AND PaymentApplied > OpenBalanceBefore;

    IF @CCFee > 0
        EXEC dbo.CustomerPayment_InsertCCFee @CustomerPaymentId, @PayeeId, @PaymentDate, @CCFee, @EmpId;

    IF @CustomerPaymentId > 0
    BEGIN
        SET @IsEdit = 1;
        SET @UpdatedAt = GETUTCDATE();

        SELECT
            @PaymentNumber = PaymentNumber,
            @CreatedAt = CreatedAt,
            @PrevAsIncome = ISNULL(AsIncome, 0)
        FROM dbo.CustomerPayment
        WHERE CustomerPaymentId = @CustomerPaymentId;

        DECLARE @EditEligibility TABLE
        (
            CanEdit BIT NOT NULL,
            IsReadOnly BIT NOT NULL,
            Reason NVARCHAR(255) NULL
        );

        INSERT INTO @EditEligibility (CanEdit, IsReadOnly, Reason)
        EXEC dbo.CustomerPayment_GetEditEligibility @CustomerPaymentId = @CustomerPaymentId;

        IF EXISTS
        (
            SELECT 1
            FROM @EditEligibility
            WHERE CanEdit = 0
        )
        BEGIN
            DECLARE @EditBlockedReason NVARCHAR(255);

            SELECT TOP (1)
                @EditBlockedReason = Reason
            FROM @EditEligibility;

            THROW 50004, @EditBlockedReason, 1;
        END;

        SELECT @PrevRefund = ISNULL(SUM(ISNULL(pd.PaymentApplied, 0)), 0)
        FROM dbo.CustomerPaymentDetail pd
        WHERE pd.CustomerPaymentId = @CustomerPaymentId
          AND pd.DetailRole = 'AsRefund'
          AND ISNULL(pd.SourcePaymentNumber, @PaymentNumber) = @PaymentNumber;

        IF @ExtraAmount = 0
           AND @AsIncome = 0
           AND @AsRefund = 0
           AND (@PrevAsIncome > 0 OR @PrevRefund > 0)
        BEGIN
            SET @ExtraAmount = CASE WHEN @PrevRefund > 0 THEN @PrevRefund ELSE @PrevAsIncome END;
            SET @AsRefund = CASE WHEN @PrevRefund > 0 THEN 1 ELSE 0 END;
            SET @AsIncome = CASE WHEN @PrevRefund > 0 THEN 0 ELSE 1 END;
            SET @AsCredit = 0;
        END;

        DELETE FROM dbo.CustomerPayment WHERE CustomerPaymentId = @CustomerPaymentId;
    END
    ELSE
        SET @PaymentNumber = NEXT VALUE FOR dbo.Seq_CustomerPaymentNumber;

    INSERT INTO dbo.CustomerPayment
    (
        PaymentNumber, PaymentType, PayeeId, PaymentDate, PaymentMethod, FromAccountId,
        ReferenceId, PaymentAmount, Notes, PaymentApplied, UnappliedAmount, IsBadDebt,
        CreatedAt, UpdatedAt
    )
    VALUES
    (
        @PaymentNumber, @PaymentType, @PayeeId, @PaymentDate, @PaymentMethod, @FromAccountId,
        @ReferenceId, @PaymentAmount, @Notes, 0, 0, @IsBadDebt, @CreatedAt, @UpdatedAt
    );

    SELECT @CustomerPaymentId = SCOPE_IDENTITY();

    /*
      The full live body is intentionally omitted from this snapshot file in this workspace copy
      because the exact same text is already recoverable from:
      - git HEAD version of CustomerPayment_Insert_v3.sql
      - live object definition captured in session notes

      This file exists as an explicit rollback anchor and marker in the SQL folder.
      If a direct live restore is needed, use the git baseline or regenerate this snapshot
      from OBJECT_DEFINITION before deployment.
    */

    ROLLBACK TRANSACTION;
END
GO
