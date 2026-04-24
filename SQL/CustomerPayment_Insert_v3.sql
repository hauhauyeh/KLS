SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
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
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

    /*
        Plain-English overview of what this procedure does

        1. Read the user's staged temp rows for this payment save.
        2. If this is an edit, make sure it is safe to rebuild the payment.
        3. Recreate the CustomerPayment header row.
        4. Convert the staged rows into committed CustomerPaymentDetail rows.
        5. Calculate the G/L posting totals from those committed detail rows.
        6. Insert the TransactionJournal + TransactionJournalDetail rows.
        7. Recalculate this payment and any affected source payments.

        Important mental model:

        - "target rows" are invoices / debit memos / CCFee rows being paid
        - "source rows" are credits that provide value into this payment
          such as prior unapplied payments or credit memos
        - "extra disposition" means what to do with leftover money:
          leave as credit, post as income, or reserve for refund

        In the unified model, CustomerPaymentDetail is the main source of truth.
        The rest of the procedure is mostly:

        - build committed detail rows
        - derive header / G/L meaning from those detail rows
    */

    -- Phase 1. Normalize inputs and declare working variables.
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

    -- #AffectedSourcePayment:
    -- list of older customer payments that are acting as source credit.
    -- If this save consumes or releases any of those source payments,
    -- their header balances must be recalculated at the end.
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

    -- Phase 2. Edit cleanup:
    -- if this is an edit, collect the old source-payment links first so those
    -- source headers can be recalculated later, then clear any old temp CCFee helper rows.
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

    -- Phase 1A. Normalize payment-type behavior and source document identity.
    --
    -- Some payment types have special behavior:
    -- - Bad Debt behaves like a write-off, so there is no normal payment method
    -- - Credit Apply also does not use a normal payment method
    -- - Customer Refund posts as a different source document type than Customer Payment
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

    -- Phase 1B. Read the user's extra-money choice from TempExtraPayment.
    --
    -- This is the leftover-amount decision made in the UI:
    -- - AsCredit: leave leftover as unapplied credit
    -- - AsIncome: recognize leftover as income
    -- - AsRefund: reserve leftover for later refund issuance
    SELECT
        @AsCredit = AsCredit,
        @AsIncome = AsIncome,
        @AsRefund = AsRefund,
        @ExtraAmount = ExtraAmount
    FROM dbo.TempExtraPayment
    WHERE PayeeId = @PayeeId
      AND CustomerPaymentId = @CustomerPaymentId;

    -- Phase 1C. Leave-as-credit pre-adjustment.
    --
    -- If the user chose "Leave as credit", do not let the staged invoice/debit
    -- applications exceed the document's remaining open balance.
    -- The excess stays unapplied instead of over-applying the target row.
    IF (@AsCredit = 1)
        UPDATE dbo.TempCustomerPayment
        SET PaymentApplied = OpenBalanceBefore - DiscountApplied
        WHERE EmpId = @EmpId
          AND PayeeId = @PayeeId
          AND CustomerPaymentId = @CustomerPaymentId
          AND ISNULL(IsSelected, IsApplied) = 1
          AND SourceType IN ('Invoice', 'DebitMemo')
          AND PaymentApplied > OpenBalanceBefore;

    -- Phase 1D. Insert or refresh credit-card fee helper rows before save.
    --
    -- CCFee behaves like a generated target document. We create/refresh it now
    -- so the later detail-building and posting logic can treat it like a normal row.
    IF @CCFee > 0
        EXEC dbo.CustomerPayment_InsertCCFee @CustomerPaymentId, @PayeeId, @PaymentDate, @CCFee, @EmpId;

    -- Phase 2A. Edit/new header handling.
    --
    -- If this is an edit:
    -- - capture the old payment number / date / timestamps
    -- - make sure editing is still allowed
    -- - preserve prior extra-disposition intent if the current temp state no longer carries it
    -- - delete the old header so this procedure can rebuild the payment cleanly
    --
    -- If this is a new payment:
    -- - take the next payment number from the sequence
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

        -- Phase 2A.a. Edit-safety guard.
        --
        -- This procedure no longer owns its own dependency traversal.
        -- It now asks the shared read-only eligibility procedure for one answer.
        --
        -- That keeps:
        -- - UI precheck
        -- - backend endpoint
        -- - SQL save guard
        --
        -- on the same rule.
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

        -- Preserve prior extra-disposition intent if the current temp request no longer
        -- carries it. This mainly matters for edit scenarios where the header is being
        -- rebuilt but the user did not actively reopen/change the extra dialog.
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

        -- Delete the old header now. The delete trigger cleans dependent committed rows.
        -- After this point the procedure rebuilds the payment from staged temp truth.
        DELETE FROM dbo.CustomerPayment WHERE CustomerPaymentId = @CustomerPaymentId;
    END
    ELSE
        SET @PaymentNumber = NEXT VALUE FOR dbo.Seq_CustomerPaymentNumber;

    -- Phase 3. Insert the new/rebuilt CustomerPayment header row.
    --
    -- Header totals start at zero here.
    -- They are recalculated after committed detail rows and G/L rows are created.
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

    -- Phase 4. Snapshot the selected temp rows into #SelectedTemp.
    --
    -- Why this table exists:
    -- once save begins, we want one stable in-memory set of rows to work from.
    -- That avoids repeatedly reading TempCustomerPayment while we are consuming it.
    --
    -- In plain words:
    -- #SelectedTemp = "the exact staged rows the user chose to save right now"
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

    -- Phase 4A. Validate corporate-payment scope before allocation.
    --
    -- Corporate Payment is stricter:
    -- every selected target/source row must belong to the same bill family.
    -- If not, saving is blocked before any committed rows are written.
    IF @PaymentType = 'Corporate Payment'
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Customer c
            WHERE c.PayeeId = @PayeeId
              AND c.BillId = @PayeeId
              AND EXISTS (
                    SELECT 1
                    FROM dbo.Customer c2
                    WHERE c2.BillId = c.BillId
                      AND c2.PayeeId <> c.PayeeId
              )
        )
            THROW 50001, 'Corporate Payment requires a valid corporate billing account.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM #SelectedTemp st
            INNER JOIN dbo.Sales s ON s.SalesId = st.SalesId
            WHERE st.SourceType IN ('Invoice', 'DebitMemo', 'CreditMemo', 'CCFee')
              AND ISNULL(s.BillId, 0) <> @PayeeId
        )
            THROW 50002, 'Corporate Payment can only apply documents from the selected bill family.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM #SelectedTemp st
            INNER JOIN dbo.CustomerPayment cp ON cp.CustomerPaymentId = st.SourceId
            WHERE st.SourceType = 'UnappliedPayment'
              AND ISNULL(cp.PayeeId, 0) <> @PayeeId
        )
            THROW 50003, 'Corporate Payment can only use unapplied payments from the selected corporate account.', 1;
    END;

    -- Phase 4B. Build the unapplied-payment source pool.
    --
    -- This comes from selected "UnappliedPayment" temp rows.
    -- Each row in #UnappliedPool says:
    -- - which older payment is being used as source credit
    -- - how much source credit is still available to consume
    --
    -- Later phases consume this pool in order to:
    -- - fund invoice/debit-memo applications
    -- - fund AsIncome rows
    SELECT @PriorUnappliedUsed = ISNULL(SUM(ABS(PaymentApplied)), 0)
    FROM #SelectedTemp
    WHERE SourceType = 'UnappliedPayment';

    CREATE TABLE #UnappliedPool
    (
        RowId INT IDENTITY(1,1) PRIMARY KEY,
        SourcePaymentNumber INT,
        SourceCustomerPaymentId INT,
        RemainingAmount DECIMAL(18,2)
    );

    INSERT INTO #UnappliedPool(SourcePaymentNumber, SourceCustomerPaymentId, RemainingAmount)
    SELECT cp.PaymentNumber, cp.CustomerPaymentId, ABS(st.PaymentApplied)
    FROM #SelectedTemp st
    INNER JOIN dbo.CustomerPayment cp ON cp.CustomerPaymentId = st.SourceId
    WHERE st.SourceType = 'UnappliedPayment'
      AND ABS(st.PaymentApplied) > 0
    ORDER BY st.TempCPId;

    -- Phase 5. Build committed CustomerPaymentDetail rows.
    --
    -- This is the heart of the unified model.
    -- After this phase, the payment meaning should be explainable from
    -- CustomerPaymentDetail rows alone.

    -- Phase 5A. Insert direct detail rows that do not require allocation logic.
    --
    -- These rows already know exactly what they are:
    -- - CreditMemo source rows
    -- - CCFee target rows
    --
    -- So we can insert them directly without walking the unapplied-payment pool.
    -- Transitional note:
    -- CustomerPaymentDetail.SalesId is still NOT NULL in the current schema, so source-side rows
    -- keep SalesId populated for compatibility even when SourceSalesId is the new semantic field.
    -- DiscountApplied is a computed column in the live table. The procedure writes the three
    -- component discount fields only, and SQL Server computes the rolled-up total automatically.
    INSERT INTO dbo.CustomerPaymentDetail
    (
        CustomerPaymentId, SalesId, PaymentApplied, PaymentDiscount, ShortDiscount,
        OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber,
        DetailRole, SourceCustomerPaymentId, SourceSalesId
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
        NULL,
        'CreditMemo',
        NULL,
        SalesId
    FROM #SelectedTemp
    WHERE SourceType = 'CreditMemo';

    INSERT INTO dbo.CustomerPaymentDetail
    (
        CustomerPaymentId, SalesId, PaymentApplied, PaymentDiscount, ShortDiscount,
        OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber,
        DetailRole, SourceCustomerPaymentId, SourceSalesId
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
        NULL,
        'CCFee',
        NULL,
        NULL
    FROM #SelectedTemp
    WHERE SourceType = 'CCFee';

    -- Phase 5B. Allocate invoice/debit-memo targets.
    --
    -- For each invoice/debit-memo target:
    -- 1. consume prior unapplied source rows first, if the user selected any
    -- 2. write target detail rows that point back to those source payments
    -- 3. if any amount still remains, write it as this payment's own direct application
    --
    -- Result:
    -- one target document may become multiple detail rows if it is funded by
    -- multiple prior unapplied source payments plus current cash.
    -- Transitional note:
    -- when a target is funded by a prior unapplied payment, Phase 3 keeps the target DetailRole
    -- and records the dependency through SourceCustomerPaymentId / SourcePaymentNumber so edit/load
    -- compatibility is preserved before later phases rewrite the read path.
    -- #PositiveTargets:
    -- ordered working list of invoice/debit-memo targets that still need the
    -- source-allocation loop described above.
    CREATE TABLE #PositiveTargets
    (
        RowId INT IDENTITY(1,1) PRIMARY KEY,
        SalesId INT,
        DetailRole NVARCHAR(30),
        PaymentApplied DECIMAL(18,2),
        PaymentDiscount DECIMAL(18,2),
        ShortDiscount DECIMAL(18,2),
        OtherDiscount DECIMAL(18,2)
    );

    INSERT INTO #PositiveTargets(SalesId, DetailRole, PaymentApplied, PaymentDiscount, ShortDiscount, OtherDiscount)
    SELECT SalesId, SourceType, PaymentApplied, PaymentDiscount, ShortDiscount, OtherDiscount
    FROM #SelectedTemp
    WHERE SourceType IN ('Invoice', 'DebitMemo')
    ORDER BY TempCPId;

    -- Working variables for the invoice/debit-memo allocation loop.
    -- This loop is row-oriented on purpose because it needs to walk target rows
    -- in order and decrement the running unapplied pool as it goes.
    DECLARE @TargetRowId INT = 1;
    DECLARE @TargetMaxRow INT;
    DECLARE @PoolRowId INT;
    DECLARE @PoolMaxRow INT;
    DECLARE @TargetSalesId INT;
    DECLARE @TargetDetailRole NVARCHAR(30);
    DECLARE @TargetApplied DECIMAL(18,2);
    DECLARE @TargetPmtDisc DECIMAL(18,2);
    DECLARE @TargetShort DECIMAL(18,2);
    DECLARE @TargetOther DECIMAL(18,2);
    DECLARE @RemainingTarget DECIMAL(18,2);
    DECLARE @SourcePaymentId INT;
    DECLARE @SourceCustomerPaymentId INT;
    DECLARE @SourceRemaining DECIMAL(18,2);
    DECLARE @ApplyFromSource DECIMAL(18,2);

    SELECT @TargetMaxRow = COUNT(*) FROM #PositiveTargets;

    WHILE @TargetRowId <= ISNULL(@TargetMaxRow, 0)
    BEGIN
        SELECT
            @TargetSalesId = SalesId,
            @TargetDetailRole = DetailRole,
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
                @SourceCustomerPaymentId = SourceCustomerPaymentId,
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
                    OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber,
                    DetailRole, SourceCustomerPaymentId, SourceSalesId
                )
                VALUES
                (
                    @CustomerPaymentId, @TargetSalesId, @ApplyFromSource, 0, 0, 0, 0, 0, @SourcePaymentId,
                    @TargetDetailRole, @SourceCustomerPaymentId, NULL
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
                OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber,
                DetailRole, SourceCustomerPaymentId, SourceSalesId
            )
            VALUES
            (
                @CustomerPaymentId, @TargetSalesId, @RemainingTarget, @TargetPmtDisc, @TargetShort, @TargetOther, 0, 0, NULL,
                @TargetDetailRole, NULL, NULL
            );
        END;

        SET @TargetRowId += 1;
    END;

    -- Phase 6. Build unified extra-disposition detail rows.
    --
    -- These are the rows that explain what happened to leftover money after
    -- normal document application.

    -- Phase 6A. Build AsIncome rows.
    --
    -- If leftover money is posted as income:
    -- - first consume prior unapplied source rows if available
    -- - if there is still remainder, create a self-funded AsIncome row
    --
    -- That keeps the source chain explicit:
    -- - "income funded by prior source payment"
    -- - or "income funded by this payment itself"
    IF @AsIncome = 1 AND @ExtraAmount > 0
    BEGIN
        DECLARE @IncomeRemaining DECIMAL(18,2) = @ExtraAmount;
        DECLARE @IncomePoolRowId INT = 1;
        DECLARE @IncomePoolMax INT;
        DECLARE @IncomeSourcePmtNum INT;
        DECLARE @IncomeSourceCustomerPaymentId INT;
        DECLARE @IncomeSourceRemaining DECIMAL(18,2);
        DECLARE @IncomeApply DECIMAL(18,2);

        SELECT @IncomePoolMax = COUNT(*) FROM #UnappliedPool;

        WHILE @IncomePoolRowId <= ISNULL(@IncomePoolMax, 0) AND @IncomeRemaining > 0
        BEGIN
            SELECT
                @IncomeSourcePmtNum = SourcePaymentNumber,
                @IncomeSourceCustomerPaymentId = SourceCustomerPaymentId,
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

                INSERT INTO dbo.CustomerPaymentDetail
                (
                    CustomerPaymentId, SalesId, PaymentApplied, PaymentDiscount, ShortDiscount,
                    OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber,
                    DetailRole, SourceCustomerPaymentId, SourceSalesId
                )
                VALUES
                (
                    @CustomerPaymentId, 0, @IncomeApply, 0, 0, 0, 0, 0, @IncomeSourcePmtNum,
                    'AsIncome', @IncomeSourceCustomerPaymentId, NULL
                );

                UPDATE #UnappliedPool
                SET RemainingAmount = RemainingAmount - @IncomeApply
                WHERE RowId = @IncomePoolRowId;

                SET @IncomeRemaining = @IncomeRemaining - @IncomeApply;
            END;

            SET @IncomePoolRowId += 1;
        END;

        IF @IncomeRemaining > 0
        BEGIN
            INSERT INTO dbo.CustomerPaymentDetail
            (
                CustomerPaymentId, SalesId, PaymentApplied, PaymentDiscount, ShortDiscount,
                OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber,
                DetailRole, SourceCustomerPaymentId, SourceSalesId
            )
            VALUES
            (
                @CustomerPaymentId, 0, @IncomeRemaining, 0, 0, 0, 0, 0, @PaymentNumber,
                'AsIncome', @CustomerPaymentId, NULL
            );
        END;
    END;

    -- Phase 6B. Build AsRefund row.
    --
    -- This row means:
    -- "this amount is reserved for later refund issuance"
    --
    -- It points back to this payment as its own source, and later the refund
    -- queue / issue-refund flow uses this row as the source of truth.
    --
    -- SalesId remains 0 only because the legacy schema still requires a non-null
    -- SalesId even for non-target extra-disposition rows.
    IF @AsRefund = 1 AND @ExtraAmount > 0
    BEGIN
        -- Reserve this extra amount for later refund issuance.
        INSERT INTO dbo.CustomerPaymentDetail
        (
            CustomerPaymentId, SalesId, PaymentApplied, PaymentDiscount, ShortDiscount,
            OtherDiscount, IsCreditMemo, IsCCFee, SourcePaymentNumber,
            DetailRole, SourceCustomerPaymentId, SourceSalesId
        )
        VALUES
        (
            @CustomerPaymentId, 0, @ExtraAmount, 0, 0, 0, 0, 0, @PaymentNumber,
            'AsRefund', @CustomerPaymentId, NULL
        );
    END;

    -- Phase 6C. Refresh immediate source/payment-side state.
    --
    -- After writing committed detail rows:
    -- - decrease UnappliedAmount on any source payments used by this save
    -- - capture all source payment numbers that must be recalculated later
    -- - refresh sales-level state through CustomerPayment_UpdateSales
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
    SELECT DISTINCT cp.PaymentNumber
    FROM dbo.CustomerPaymentDetail pd
    INNER JOIN dbo.CustomerPayment cp
        ON cp.CustomerPaymentId = pd.SourceCustomerPaymentId
    WHERE pd.CustomerPaymentId = @CustomerPaymentId
      AND pd.SourceCustomerPaymentId IS NOT NULL
      AND NOT EXISTS (
            SELECT 1
            FROM #AffectedSourcePayment a
            WHERE a.PaymentNumber = cp.PaymentNumber
      );

    EXEC dbo.CustomerPayment_UpdateSales @CustomerPaymentId, 0;

    -- Phase 7. Calculate posting totals from committed detail rows.
    --
    -- At this point the procedure stops looking at temp meaning and starts looking
    -- only at committed detail truth.
    --
    -- These variables summarize the payment in accounting terms:
    -- - how much cash/normal application happened
    -- - how much credit memo was used
    -- - how much prior unapplied source was used
    -- - how much discount was taken
    -- - whether any extra amount became income

    SELECT @CreditMemoUsed = ISNULL(SUM(ISNULL(PaymentApplied, 0) * -1), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId
      AND IsCreditMemo = 1
      AND PaymentApplied < 0;

    SELECT @CashApplied = ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId
      AND DetailRole IN ('Invoice', 'DebitMemo', 'CCFee')
      AND ISNULL(SourceCustomerPaymentId, 0) = 0;

    SET @CashApplied = @CashApplied - @CreditMemoUsed;

    SELECT @TotalDiscountApplied = ISNULL(SUM(ISNULL(DiscountApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId;

    SELECT @PriorUnappliedUsed = ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId
      AND DetailRole IN ('Invoice', 'DebitMemo', 'CCFee')
      AND ISNULL(SourceCustomerPaymentId, 0) <> 0;

    SET @AR = @PaymentAmount + @TotalDiscountApplied;

    IF @IsBadDebt = 1
        SET @AR = @CashApplied + @TotalDiscountApplied;

    IF @AsIncome = 1
        SET @AR = @AR - @ExtraAmount;

    -- Phase 7A. Translate business totals into journal posting amounts.
    --
    -- This makes the G/L section easier to read:
    -- each later journal insert uses a named posting variable rather than
    -- repeating mixed inline formulas.
    --
    -- Discount rule:
    -- the G/L discount total must represent the full customer discount taken on targets.
    -- In this payment module that total discount is:
    -- - PaymentDiscount
    -- - plus ShortDiscount
    -- - plus OtherDiscount
    --
    -- Those three together are treated as the target row's total DiscountApplied.
    DECLARE @PostAR DECIMAL(18,2) = @AR * -1;
    DECLARE @PostBadDebtCash DECIMAL(18,2) = @CashApplied;
    DECLARE @PostBadDebtDiscount DECIMAL(18,2) = @TotalDiscountApplied;
    DECLARE @PostUF DECIMAL(18,2) = @PaymentAmount;
    DECLARE @PostIDG DECIMAL(18,2) = @TotalDiscountApplied;
    -- Reuse of prior unapplied payments or credit memos creates no new G/L.
    -- Those source documents already created their own accounting when they were created.
    DECLARE @PostIOTReuse DECIMAL(18,2) = 0;
    DECLARE @PostIOTAsIncome DECIMAL(18,2) = @ExtraAmount;

    -- Phase 8. Insert TransactionJournal header.
    --
    -- Only after posting totals are known do we create the journal header.
    INSERT INTO dbo.TransactionJournal
    (
        TxDate, TxTime, SourceDocOrder, SourceDocType, SourceDocNumber, Notes
    )
    VALUES
    (
        @PaymentDate, GETUTCDATE(), @SourceDocOrder, @SourceDocType, @PaymentNumber, @Notes
    );

    SELECT @TxId = SCOPE_IDENTITY();

    -- Phase 9. Insert TransactionJournalDetail rows.
    --
    -- These lines are the actual accounting result of the save.

    -- Phase 9A. Post the AR control line.
    --
    -- Every customer payment save balances around AR.
    SET @Amount = @PostAR;
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

    -- Phase 9B. Post the balancing side.
    --
    -- Bad Debt path:
    -- - instead of normal payment accounts, AR is balanced by bad-debt expense
    --
    -- Normal payment path:
    -- - UF = original payment amount
    -- - IDG = discount given
    -- - IOT = reused value from credit memo or prior unapplied source
    IF @IsBadDebt = 1
    BEGIN
        IF @PostBadDebtCash <> 0
        BEGIN
            SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@EBAD';
            SET @Amount = @PostBadDebtCash;
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

        IF @PostBadDebtDiscount <> 0
        BEGIN
            SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@EBAD';
            SET @Amount = @PostBadDebtDiscount;
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
    END
    ELSE
    BEGIN
        -- 19A. Post the base payment amount.
        --
        -- Normal payment:
        -- - post against UF
        --
        -- Customer refund:
        -- - post against the actual refund bank/cash account
        IF @PaymentType = 'Customer Refund'
            SET @AccountId = @FromAccountId;
        ELSE
            SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@UF';

        SET @Amount = @PostUF;
        EXEC dbo.Fn_Adjust_CrDeAmount @AccountId, @Amount, @CrDeAmount OUTPUT;

        INSERT INTO dbo.TransactionJournalDetail
        (
            TxId, AccountId, PayeeId, Amount, CrDeAmount
        )
        VALUES
        (
            @TxId, @AccountId, @PayeeId, @Amount, @CrDeAmount
        );

        -- 19B. Post discount-given line.
        IF @PostIDG <> 0
        BEGIN
            SET @Amount = @PostIDG;
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

        -- 19C. Reuse of prior credit creates no new G/L.
        --
        -- Business rule:
        -- - prior unapplied reuse = no G/L
        -- - credit memo reuse = no G/L
        --
        -- So this block is intentionally inert in the unified model.
        IF @PostIOTReuse <> 0
        BEGIN
            SET @Amount = @PostIOTReuse;
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

    -- Phase 9C. Post explicit AsIncome line.
    --
    -- AsIncome gets its own dedicated IOT posting and also persists the amount
    -- onto the payment header for later header refresh logic.
    --
    -- Leave-as-credit does NOT get its own separate G/L line here.
    IF @AsIncome = 1
    BEGIN
        SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@IOT';
        SET @Amount = @PostIOTAsIncome;
        EXEC dbo.Fn_Adjust_CrDeAmount @AccountId, @Amount, @CrDeAmount OUTPUT;

        INSERT INTO dbo.TransactionJournalDetail
        (
            TxId, AccountId, PayeeId, Amount, CrDeAmount
        )
        VALUES
        (
            @TxId, @AccountId, @PayeeId, @Amount, @CrDeAmount
        );

        UPDATE dbo.CustomerPayment
        SET AsIncome = @ExtraAmount
        WHERE CustomerPaymentId = @CustomerPaymentId;
    END;

    -- Phase 9D. Post explicit AsRefund reserve reclass on the same payment document.
    --
    -- CPA rule for the reserve step:
    -- 1. original receipt still posts normally on this same document:
    --    - AR credit
    --    - UF debit
    -- 2. when the user chooses AsRefund, the same document also records the
    --    refund-reserve reclass:
    --    - AR debit
    --    - CRP credit
    --
    -- Why this block exists:
    -- - keep the model simple: one CustomerPayment header, one self AsRefund detail row
    -- - keep refund queue unchanged because it already keys off that AsRefund detail row
    -- - let the existing self AsRefund detail/header math keep representing the reserved amount
    -- - add only the missing reserve accounting required by the CPA
    --
    -- This block does not create a second header and does not move the refund into
    -- VendorPayment yet. That happens later when the refund is actually issued.
    --
    -- In other words:
    -- - CustomerPaymentDetail already says "this amount is reserved"
    -- - the header recalculation already removes that self-reserved amount from unapplied credit
    -- - this new block only adds the missing CRP / AR reserve journal lines
    IF @AsRefund = 1 AND @ExtraAmount > 0
    BEGIN
        -- Reserve line 1:
        -- debit AR to reclass the refundable amount out of normal customer credit.
        SET @Amount = @ExtraAmount;
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

        -- Reserve line 2:
        -- credit Customer Refund Payable because the company now owes this amount back.
        SET @Amount = @ExtraAmount;
        SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@CRP';
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

    -- Phase 10. Clear temp staging and run downstream recalculation.
    --
    -- Once committed rows and journal rows are in place:
    -- - clear the staged temp rows
    -- - clear the staged extra-disposition row
    -- - run inventory/accounting recalculation tied to the journal insert
    DELETE dbo.TempCustomerPayment
    WHERE EmpId = @EmpId
      AND PayeeId = @PayeeId
      AND CustomerPaymentId = CASE WHEN @IsEdit = 1 THEN @OldId ELSE 0 END;

    DELETE dbo.TempExtraPayment
    WHERE EmpId = @EmpId
      AND PayeeId = @PayeeId;

    EXEC dbo.Recalc_AfterInsert @TxId, @PaymentDate;

    -- Phase 10A. Refresh header balances from committed detail truth.
    --
    -- First refresh this payment's own header.
    -- Then refresh every source payment captured in #AffectedSourcePayment.
    --
    -- This is where the procedure turns committed detail rows back into header totals:
    -- - PaymentApplied
    -- - UnappliedAmount
    --
    -- @ConsumedByOthers means:
    -- how much of this payment's extra/source value has already been consumed
    -- by other payments downstream.
    DECLARE @ConsumedByOthers DECIMAL(18,2) = 0;
    SELECT @ConsumedByOthers = ISNULL(SUM(ISNULL(pd.PaymentApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail pd
    WHERE pd.SourceCustomerPaymentId = @CustomerPaymentId
      AND pd.CustomerPaymentId != @CustomerPaymentId;

    SELECT @SourceUseAsIncome = ISNULL(SUM(ISNULL(pd.PaymentApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail pd
    WHERE pd.CustomerPaymentId = @CustomerPaymentId
      AND pd.DetailRole = 'AsIncome'
      AND ISNULL(pd.SourceCustomerPaymentId, 0) <> @CustomerPaymentId;

    SELECT @SourceUseRefundSelf = ISNULL(SUM(ISNULL(pd.PaymentApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail pd
    WHERE pd.CustomerPaymentId = @CustomerPaymentId
      AND pd.DetailRole = 'AsRefund'
      AND ISNULL(pd.SourceCustomerPaymentId, 0) = @CustomerPaymentId;

    UPDATE dbo.CustomerPayment
    SET
        PaymentApplied = (
            SELECT ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
            FROM dbo.CustomerPaymentDetail
            WHERE CustomerPaymentId = @CustomerPaymentId
              AND DetailRole IN ('Invoice', 'DebitMemo', 'CCFee')
              AND ISNULL(SourceCustomerPaymentId, 0) = 0
        ) - @CreditMemoUsed,
        UnappliedAmount = @PaymentAmount - (
            SELECT ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
            FROM dbo.CustomerPaymentDetail
            WHERE CustomerPaymentId = @CustomerPaymentId
              AND DetailRole IN ('Invoice', 'DebitMemo', 'CCFee')
              AND ISNULL(SourceCustomerPaymentId, 0) = 0
        ) + @CreditMemoUsed - (ISNULL(AsIncome, 0) - @SourceUseAsIncome) - @SourceUseRefundSelf - @ConsumedByOthers
    WHERE CustomerPaymentId = @CustomerPaymentId;

    ;WITH SourceHeader AS
    (
        SELECT
            cp.CustomerPaymentId,
            cp.PaymentAmount,
            ISNULL(cp.AsIncome, 0) AS AsIncome,
            SourceUseRefundSelf = ISNULL((
                SELECT SUM(ISNULL(pd.PaymentApplied, 0))
                FROM dbo.CustomerPaymentDetail pd
                WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
                  AND pd.DetailRole = 'AsRefund'
                  AND ISNULL(pd.SourceCustomerPaymentId, 0) = cp.CustomerPaymentId
            ), 0),
            SourceUseAsIncome = ISNULL((
                SELECT SUM(ISNULL(pd.PaymentApplied, 0))
                FROM dbo.CustomerPaymentDetail pd
                WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
                  AND pd.DetailRole = 'AsIncome'
                  AND ISNULL(pd.SourceCustomerPaymentId, 0) <> cp.CustomerPaymentId
            ), 0),
            OwnCashApplied = ISNULL((
                SELECT SUM(ISNULL(pd.PaymentApplied, 0))
                FROM dbo.CustomerPaymentDetail pd
                WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
                  AND pd.DetailRole IN ('Invoice', 'DebitMemo', 'CCFee')
                  AND ISNULL(pd.SourceCustomerPaymentId, 0) = 0
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
                WHERE pd.SourceCustomerPaymentId = cp.CustomerPaymentId
                  AND pd.CustomerPaymentId != cp.CustomerPaymentId
            ), 0)
        FROM dbo.CustomerPayment cp
        INNER JOIN #AffectedSourcePayment a
            ON a.PaymentNumber = cp.PaymentNumber
    )
    UPDATE cp
    SET
        PaymentApplied = sh.OwnCashApplied - sh.CreditMemoUsed,
        UnappliedAmount = sh.PaymentAmount - sh.OwnCashApplied + sh.CreditMemoUsed - (sh.AsIncome - sh.SourceUseAsIncome) - sh.SourceUseRefundSelf - sh.ConsumedByOthers
    FROM dbo.CustomerPayment cp
    INNER JOIN SourceHeader sh
        ON sh.CustomerPaymentId = cp.CustomerPaymentId;

    SET @NewPaymentId = @CustomerPaymentId;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END

