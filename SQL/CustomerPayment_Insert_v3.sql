IF OBJECT_ID('dbo.CustomerPayment_Insert_prev', 'P') IS NOT NULL
    DROP PROCEDURE dbo.CustomerPayment_Insert_prev;

EXEC sp_rename 'dbo.CustomerPayment_Insert', 'CustomerPayment_Insert_prev';
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE PROCEDURE [dbo].[CustomerPayment_Insert]

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
    DECLARE @ExtraAmount DECIMAL(18,2) = 0;
    DECLARE @SourceUseAsIncome DECIMAL(18,2) = 0;

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

        INSERT INTO #AffectedSourcePayment(PaymentNumber)
        SELECT DISTINCT su.SourcePaymentNumber
        FROM dbo.CustomerPaymentSourceUse su
        WHERE su.CustomerPaymentId = @CustomerPaymentId
          AND NOT EXISTS (
                SELECT 1
                FROM #AffectedSourcePayment a
                WHERE a.PaymentNumber = su.SourcePaymentNumber
          );

        DELETE FROM dbo.CustomerPaymentSourceUse
        WHERE CustomerPaymentId = @CustomerPaymentId;

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
            @CreatedAt = CreatedAt
        FROM dbo.CustomerPayment
        WHERE CustomerPaymentId = @CustomerPaymentId;

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

    CREATE TABLE #SelectedTemp
    (
        TempCPId INT PRIMARY KEY,
        SalesId INT,
        SourceType NVARCHAR(20),
        SourceId INT,
        PaymentApplied DECIMAL(18,2),
        PaymentDiscount DECIMAL(18,2),
        ShortDiscount DECIMAL(18,2),
        OtherDiscount DECIMAL(18,2),
        DiscountApplied DECIMAL(18,2),
        IsCCFee BIT,
        OpenBalanceBefore DECIMAL(18,2)
    );

    INSERT INTO #SelectedTemp
    (
        TempCPId, SalesId, SourceType, SourceId, PaymentApplied, PaymentDiscount,
        ShortDiscount, OtherDiscount, DiscountApplied, IsCCFee, OpenBalanceBefore
    )
    SELECT
        TempCPId,
        SalesId,
        ISNULL(SourceType, CASE WHEN IsCCFee = 1 THEN 'CCFee' WHEN IsCreditMemo = 1 THEN 'CreditMemo' ELSE 'Invoice' END),
        ISNULL(SourceId, SalesId),
        ISNULL(PaymentApplied, 0),
        ISNULL(PaymentDiscount, 0),
        ISNULL(ShortDiscount, 0),
        ISNULL(OtherDiscount, 0),
        ISNULL(DiscountApplied, 0),
        IsCCFee,
        ISNULL(OpenBalanceBefore, AmountDue)
    FROM dbo.TempCustomerPayment
    WHERE EmpId = @EmpId
      AND PayeeId = @PayeeId
      AND CustomerPaymentId = CASE WHEN @IsEdit = 1 THEN @OldId ELSE 0 END
      AND ISNULL(IsSelected, IsApplied) = 1
      AND ISNULL(SourceType, '') != 'ConsumedCredit'
      AND (
            ISNULL(PaymentApplied, 0) <> 0
         OR ISNULL(DiscountApplied, 0) <> 0
         OR ISNULL(PaymentDiscount, 0) <> 0
         OR ISNULL(ShortDiscount, 0) <> 0
         OR ISNULL(OtherDiscount, 0) <> 0
      );

    SELECT @PriorUnappliedUsed = ISNULL(SUM(ABS(PaymentApplied)), 0)
    FROM #SelectedTemp
    WHERE SourceType = 'UnappliedPayment';

    CREATE TABLE #UnappliedPool
    (
        RowId INT IDENTITY(1,1) PRIMARY KEY,
        SourcePaymentNumber INT,
        RemainingAmount DECIMAL(18,2)
    );

    INSERT INTO #UnappliedPool(SourcePaymentNumber, RemainingAmount)
    SELECT cp.PaymentNumber, ABS(st.PaymentApplied)
    FROM #SelectedTemp st
    INNER JOIN dbo.CustomerPayment cp ON cp.CustomerPaymentId = st.SourceId
    WHERE st.SourceType = 'UnappliedPayment'
      AND ABS(st.PaymentApplied) > 0
    ORDER BY st.TempCPId;

    INSERT INTO dbo.CustomerPaymentDetail
    (
        CustomerPaymentId, SalesId, PaymentApplied, PaymentDiscount, ShortDiscount,
        OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber
    )
    SELECT
        @CustomerPaymentId,
        SalesId,
        PaymentApplied,
        PaymentDiscount,
        ShortDiscount,
        OtherDiscount,
        1,
        0,
        NULL
    FROM #SelectedTemp
    WHERE SourceType = 'CreditMemo';

    INSERT INTO dbo.CustomerPaymentDetail
    (
        CustomerPaymentId, SalesId, PaymentApplied, PaymentDiscount, ShortDiscount,
        OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber
    )
    SELECT
        @CustomerPaymentId,
        SalesId,
        PaymentApplied,
        0,
        0,
        0,
        0,
        1,
        NULL
    FROM #SelectedTemp
    WHERE SourceType = 'CCFee';

    CREATE TABLE #PositiveTargets
    (
        RowId INT IDENTITY(1,1) PRIMARY KEY,
        SalesId INT,
        PaymentApplied DECIMAL(18,2),
        PaymentDiscount DECIMAL(18,2),
        ShortDiscount DECIMAL(18,2),
        OtherDiscount DECIMAL(18,2)
    );

    INSERT INTO #PositiveTargets(SalesId, PaymentApplied, PaymentDiscount, ShortDiscount, OtherDiscount)
    SELECT SalesId, PaymentApplied, PaymentDiscount, ShortDiscount, OtherDiscount
    FROM #SelectedTemp
    WHERE SourceType IN ('Invoice', 'DebitMemo')
    ORDER BY TempCPId;

    DECLARE @TargetRowId INT = 1;
    DECLARE @TargetMaxRow INT;
    DECLARE @PoolRowId INT;
    DECLARE @PoolMaxRow INT;
    DECLARE @TargetSalesId INT;
    DECLARE @TargetApplied DECIMAL(18,2);
    DECLARE @TargetPmtDisc DECIMAL(18,2);
    DECLARE @TargetShort DECIMAL(18,2);
    DECLARE @TargetOther DECIMAL(18,2);
    DECLARE @RemainingTarget DECIMAL(18,2);
    DECLARE @SourcePaymentId INT;
    DECLARE @SourceRemaining DECIMAL(18,2);
    DECLARE @ApplyFromSource DECIMAL(18,2);

    SELECT @TargetMaxRow = COUNT(*) FROM #PositiveTargets;

    WHILE @TargetRowId <= ISNULL(@TargetMaxRow, 0)
    BEGIN
        SELECT
            @TargetSalesId = SalesId,
            @TargetApplied = ISNULL(PaymentApplied, 0),
            @TargetPmtDisc = ISNULL(PaymentDiscount, 0),
            @TargetShort = ISNULL(ShortDiscount, 0),
            @TargetOther = ISNULL(OtherDiscount, 0)
        FROM #PositiveTargets
        WHERE RowId = @TargetRowId;

        SET @RemainingTarget = @TargetApplied;

        SELECT @PoolMaxRow = COUNT(*) FROM #UnappliedPool;
        SET @PoolRowId = 1;

        WHILE @PoolRowId <= ISNULL(@PoolMaxRow, 0) AND @RemainingTarget > 0
        BEGIN
            SELECT
                @SourcePaymentId = SourcePaymentNumber,
                @SourceRemaining = RemainingAmount
            FROM #UnappliedPool
            WHERE RowId = @PoolRowId;

            IF ISNULL(@SourceRemaining, 0) > 0
            BEGIN
                SET @ApplyFromSource =
                    CASE
                        WHEN @SourceRemaining < @RemainingTarget THEN @SourceRemaining
                        ELSE @RemainingTarget
                    END;

                INSERT INTO dbo.CustomerPaymentDetail
                (
                    CustomerPaymentId, SalesId, PaymentApplied, PaymentDiscount, ShortDiscount,
                    OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber
                )
                VALUES
                (
                    @CustomerPaymentId, @TargetSalesId, @ApplyFromSource, 0, 0, 0, 0, 0, @SourcePaymentId
                );

                UPDATE #UnappliedPool
                SET RemainingAmount = RemainingAmount - @ApplyFromSource
                WHERE RowId = @PoolRowId;

                SET @RemainingTarget = @RemainingTarget - @ApplyFromSource;
            END;

            SET @PoolRowId += 1;
        END;

        IF @RemainingTarget <> 0 OR @TargetPmtDisc <> 0 OR @TargetShort <> 0 OR @TargetOther <> 0
        BEGIN
            INSERT INTO dbo.CustomerPaymentDetail
            (
                CustomerPaymentId, SalesId, PaymentApplied, PaymentDiscount, ShortDiscount,
                OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber
            )
            VALUES
            (
                @CustomerPaymentId, @TargetSalesId, @RemainingTarget, @TargetPmtDisc, @TargetShort, @TargetOther, 0, 0, NULL
            );
        END;

        SET @TargetRowId += 1;
    END;

    IF @AsIncome = 1 AND @ExtraAmount > 0
    BEGIN
        DECLARE @IncomeRemaining DECIMAL(18,2) = @ExtraAmount;
        DECLARE @IncomePoolRowId INT = 1;
        DECLARE @IncomePoolMax INT;
        DECLARE @IncomeSourcePmtNum INT;
        DECLARE @IncomeSourceRemaining DECIMAL(18,2);
        DECLARE @IncomeApply DECIMAL(18,2);

        SELECT @IncomePoolMax = COUNT(*) FROM #UnappliedPool;

        WHILE @IncomePoolRowId <= ISNULL(@IncomePoolMax, 0) AND @IncomeRemaining > 0
        BEGIN
            SELECT
                @IncomeSourcePmtNum = SourcePaymentNumber,
                @IncomeSourceRemaining = RemainingAmount
            FROM #UnappliedPool
            WHERE RowId = @IncomePoolRowId;

            IF ISNULL(@IncomeSourceRemaining, 0) > 0
            BEGIN
                SET @IncomeApply =
                    CASE
                        WHEN @IncomeSourceRemaining < @IncomeRemaining THEN @IncomeSourceRemaining
                        ELSE @IncomeRemaining
                    END;

                INSERT INTO dbo.CustomerPaymentSourceUse
                (
                    CustomerPaymentId, SourcePaymentNumber, UseType, Amount
                )
                VALUES
                (
                    @CustomerPaymentId, @IncomeSourcePmtNum, 'AsIncome', @IncomeApply
                );

                UPDATE #UnappliedPool
                SET RemainingAmount = RemainingAmount - @IncomeApply
                WHERE RowId = @IncomePoolRowId;

                SET @IncomeRemaining = @IncomeRemaining - @IncomeApply;
            END;

            SET @IncomePoolRowId += 1;
        END;
    END;

    UPDATE cp
    SET cp.UnappliedAmount = cp.UnappliedAmount - x.UsedAmount
    FROM dbo.CustomerPayment cp
    INNER JOIN (
        SELECT SourcePaymentNumber, SUM(ISNULL(PaymentApplied, 0)) AS UsedAmount
        FROM dbo.CustomerPaymentDetail
        WHERE CustomerPaymentId = @CustomerPaymentId
          AND SourcePaymentNumber IS NOT NULL
        GROUP BY SourcePaymentNumber
    ) x ON x.SourcePaymentNumber = cp.PaymentNumber;

    INSERT INTO #AffectedSourcePayment(PaymentNumber)
    SELECT DISTINCT pd.SourcePaymentNumber
    FROM dbo.CustomerPaymentDetail pd
    WHERE pd.CustomerPaymentId = @CustomerPaymentId
      AND pd.SourcePaymentNumber IS NOT NULL
      AND NOT EXISTS (
            SELECT 1
            FROM #AffectedSourcePayment a
            WHERE a.PaymentNumber = pd.SourcePaymentNumber
      );

    INSERT INTO #AffectedSourcePayment(PaymentNumber)
    SELECT DISTINCT su.SourcePaymentNumber
    FROM dbo.CustomerPaymentSourceUse su
    WHERE su.CustomerPaymentId = @CustomerPaymentId
      AND NOT EXISTS (
            SELECT 1
            FROM #AffectedSourcePayment a
            WHERE a.PaymentNumber = su.SourcePaymentNumber
      );

    EXEC dbo.CustomerPayment_UpdateSales @CustomerPaymentId, 0;

    INSERT INTO dbo.TransactionJournal
    (
        TxDate, TxTime, SourceDocOrder, SourceDocType, SourceDocNumber, Notes
    )
    VALUES
    (
        @PaymentDate, GETUTCDATE(), @SourceDocOrder, @SourceDocType, @PaymentNumber, @Notes
    );

    SELECT @TxId = SCOPE_IDENTITY();

    SELECT @CreditMemoUsed = ISNULL(SUM(ISNULL(PaymentApplied, 0) * -1), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId
      AND IsCreditMemo = 1
      AND PaymentApplied < 0;

    SELECT @CashApplied = ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId
      AND IsCreditMemo = 0
      AND IsCCFee = 0
      AND SourcePaymentNumber IS NULL;

    SET @CashApplied = @CashApplied - @CreditMemoUsed;

    SELECT @TotalDiscountApplied = ISNULL(SUM(ISNULL(DiscountApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId;

    SELECT @PriorUnappliedUsed = ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId
      AND SourcePaymentNumber IS NOT NULL;

    SET @AR = @PaymentAmount + @TotalDiscountApplied;

    IF @IsBadDebt = 1
        SET @AR = @CashApplied + @TotalDiscountApplied;

    IF @AsIncome = 1
        SET @AR = @AR - @ExtraAmount;

    IF @CreditMemoUsed > 0
        SET @AR = @AR + @CreditMemoUsed;

    IF @PriorUnappliedUsed > 0
        SET @AR = @AR + @PriorUnappliedUsed;

    SET @Amount = @AR * -1;
    SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@AR';
    EXEC dbo.Fn_Adjust_CrDeAmount @AccountId, @Amount, @CrDeAmount OUTPUT;

    INSERT INTO dbo.TransactionJournalDetail
    (
        TxId, AccountId, PayeeId, Amount, CrDeAmount
    )
    VALUES
    (
        @TxId, @AccountId, @PayeeId, @Amount, @CrDeAmount
    );

    IF @IsBadDebt = 1
    BEGIN
        IF @CashApplied <> 0
        BEGIN
            SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@EBAD';
            EXEC dbo.Fn_Adjust_CrDeAmount @AccountId, @CashApplied, @CrDeAmount OUTPUT;

            INSERT INTO dbo.TransactionJournalDetail
            (
                TxId, AccountId, PayeeId, Amount, CrDeAmount
            )
            VALUES
            (
                @TxId, @AccountId, @PayeeId, @CashApplied, @CrDeAmount
            );
        END;

        IF @TotalDiscountApplied <> 0
        BEGIN
            SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@EBAD';
            EXEC dbo.Fn_Adjust_CrDeAmount @AccountId, @TotalDiscountApplied, @CrDeAmount OUTPUT;

            INSERT INTO dbo.TransactionJournalDetail
            (
                TxId, AccountId, PayeeId, Amount, CrDeAmount
            )
            VALUES
            (
                @TxId, @AccountId, @PayeeId, @TotalDiscountApplied, @CrDeAmount
            );
        END;
    END
    ELSE
    BEGIN
        IF @PaymentType = 'Customer Refund'
            SET @AccountId = @FromAccountId;
        ELSE
            SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@UF';

        EXEC dbo.Fn_Adjust_CrDeAmount @AccountId, @PaymentAmount, @CrDeAmount OUTPUT;

        INSERT INTO dbo.TransactionJournalDetail
        (
            TxId, AccountId, PayeeId, Amount, CrDeAmount
        )
        VALUES
        (
            @TxId, @AccountId, @PayeeId, @PaymentAmount, @CrDeAmount
        );

        IF @TotalDiscountApplied <> 0
        BEGIN
            SET @Amount = @TotalDiscountApplied * -1;
            SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@IDG';
            EXEC dbo.Fn_Adjust_CrDeAmount @AccountId, @Amount, @CrDeAmount OUTPUT;

            INSERT INTO dbo.TransactionJournalDetail
            (
                TxId, AccountId, PayeeId, Amount, CrDeAmount
            )
            VALUES
            (
                @TxId, @AccountId, @PayeeId, @Amount, @CrDeAmount
            );
        END;

        IF @CreditMemoUsed > 0 OR @PriorUnappliedUsed > 0
        BEGIN
            SET @Amount = (@CreditMemoUsed + @PriorUnappliedUsed) * -1;
            SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@IOT';
            EXEC dbo.Fn_Adjust_CrDeAmount @AccountId, @Amount, @CrDeAmount OUTPUT;

            INSERT INTO dbo.TransactionJournalDetail
            (
                TxId, AccountId, PayeeId, Amount, CrDeAmount
            )
            VALUES
            (
                @TxId, @AccountId, @PayeeId, @Amount, @CrDeAmount
            );
        END;
    END;

    IF @AsIncome = 1
    BEGIN
        SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@IOT';
        EXEC dbo.Fn_Adjust_CrDeAmount @AccountId, @ExtraAmount, @CrDeAmount OUTPUT;

        INSERT INTO dbo.TransactionJournalDetail
        (
            TxId, AccountId, PayeeId, Amount, CrDeAmount
        )
        VALUES
        (
            @TxId, @AccountId, @PayeeId, @ExtraAmount, @CrDeAmount
        );

        UPDATE dbo.CustomerPayment
        SET AsIncome = @ExtraAmount
        WHERE CustomerPaymentId = @CustomerPaymentId;
    END;

    DELETE dbo.TempCustomerPayment
    WHERE EmpId = @EmpId
      AND PayeeId = @PayeeId
      AND CustomerPaymentId = CASE WHEN @IsEdit = 1 THEN @OldId ELSE 0 END;

    DELETE dbo.TempExtraPayment
    WHERE EmpId = @EmpId
      AND PayeeId = @PayeeId;

    EXEC dbo.Recalc_AfterInsert @TxId, @PaymentDate;

    -- Compute how much of this payment's extra has been consumed by OTHER payments
    DECLARE @ConsumedByOthers DECIMAL(18,2) = 0;
    SELECT @ConsumedByOthers = ISNULL(SUM(ISNULL(pd.PaymentApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail pd
    WHERE pd.SourcePaymentNumber = @PaymentNumber
      AND pd.CustomerPaymentId != @CustomerPaymentId;

    SELECT @SourceUseAsIncome = ISNULL(SUM(ISNULL(su.Amount, 0)), 0)
    FROM dbo.CustomerPaymentSourceUse su
    WHERE su.CustomerPaymentId = @CustomerPaymentId
      AND su.UseType = 'AsIncome';

    UPDATE dbo.CustomerPayment
    SET
        PaymentApplied = (
            SELECT ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
            FROM dbo.CustomerPaymentDetail
            WHERE CustomerPaymentId = @CustomerPaymentId
              AND IsCreditMemo = 0
              AND SourcePaymentNumber IS NULL
        ) - @CreditMemoUsed,
        UnappliedAmount = @PaymentAmount - (
            SELECT ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
            FROM dbo.CustomerPaymentDetail
            WHERE CustomerPaymentId = @CustomerPaymentId
              AND IsCreditMemo = 0
              AND SourcePaymentNumber IS NULL
        ) + @CreditMemoUsed - (ISNULL(AsIncome, 0) - @SourceUseAsIncome) - @ConsumedByOthers
    WHERE CustomerPaymentId = @CustomerPaymentId;

    ;WITH SourceHeader AS
    (
        SELECT
            cp.CustomerPaymentId,
            cp.PaymentAmount,
            ISNULL(cp.AsIncome, 0) AS AsIncome,
            SourceUseAsIncome = ISNULL((
                SELECT SUM(ISNULL(su.Amount, 0))
                FROM dbo.CustomerPaymentSourceUse su
                WHERE su.CustomerPaymentId = cp.CustomerPaymentId
                  AND su.UseType = 'AsIncome'
            ), 0),
            OwnCashApplied = ISNULL((
                SELECT SUM(ISNULL(pd.PaymentApplied, 0))
                FROM dbo.CustomerPaymentDetail pd
                WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
                  AND pd.IsCreditMemo = 0
                  AND pd.SourcePaymentNumber IS NULL
            ), 0),
            CreditMemoUsed = ISNULL((
                SELECT SUM(CASE WHEN pd.PaymentApplied < 0 THEN ISNULL(pd.PaymentApplied, 0) * -1 ELSE 0 END)
                FROM dbo.CustomerPaymentDetail pd
                WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
                  AND pd.IsCreditMemo = 1
            ), 0),
            ConsumedByOthers = ISNULL((
                SELECT SUM(ISNULL(pd.PaymentApplied, 0))
                FROM dbo.CustomerPaymentDetail pd
                WHERE pd.SourcePaymentNumber = cp.PaymentNumber
                  AND pd.CustomerPaymentId != cp.CustomerPaymentId
            ), 0) + ISNULL((
                SELECT SUM(ISNULL(su.Amount, 0))
                FROM dbo.CustomerPaymentSourceUse su
                WHERE su.SourcePaymentNumber = cp.PaymentNumber
                  AND su.CustomerPaymentId != cp.CustomerPaymentId
            ), 0)
        FROM dbo.CustomerPayment cp
        INNER JOIN #AffectedSourcePayment a
            ON a.PaymentNumber = cp.PaymentNumber
    )
    UPDATE cp
    SET
        PaymentApplied = sh.OwnCashApplied - sh.CreditMemoUsed,
        UnappliedAmount = sh.PaymentAmount - sh.OwnCashApplied + sh.CreditMemoUsed - (sh.AsIncome - sh.SourceUseAsIncome) - sh.ConsumedByOthers
    FROM dbo.CustomerPayment cp
    INNER JOIN SourceHeader sh
        ON sh.CustomerPaymentId = cp.CustomerPaymentId;

    SET @NewPaymentId = @CustomerPaymentId;
END
GO
