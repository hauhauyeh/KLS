-- =====================================================================
-- CustomerPayment_Insert
--
-- 2026-05-13 change scope (Round 2):
--   Two follow-ups from the Round 1 (2026-05-11) locked-edit fix review.
--
--   Item 1 (defensive over-application check):
--     End of Phase 7, before Phase 7A. If a buggy or tampered caller
--     submits apply rows that exceed @PaymentAmount - prior_disposition -
--     prior_CCFee, the SP previously over-allocated AR silently. New
--     invariant THROWs 50012 when expected <> @PaymentAmount, gated on
--     @AsCredit = 0 AND @IsBadDebt = 0 (AsCredit absorbs leftover by
--     design; IsBadDebt balances differently).
--
--   Item 2 (unlocked-rebuild column completeness):
--     Phase 3's unlocked INSERT previously named only 14 columns, which
--     wiped CardType/Last4 (set by InsertFromGateway, never re-set on
--     edit) and AccountId1..4/Amount1..4 (split-deposit fields set
--     elsewhere) on every unlocked edit. Live audit on 2026-05-13:
--     338 unlocked rows had CardType set, 3 had split fields set.
--     Preserve all 10 via @Prev* captured in the early-read block and
--     re-applied in the unlocked INSERT VALUES.
--
--     Skipped per audit (no current live risk): NSF columns
--     (IsReturned/ReturnType/ReturnDate/FeeAccountId/FeeAmount/
--     ReturnNotes/ReturnSalesId) - the NSF flow always pairs with
--     IsLocked=1 so the unlocked rebuild never wipes them in practice.
--     Also skipped: VendorPaymentId - the column is dead on this table
--     (zero rows populated, zero writers). Recommend separate cleanup.
--
--   Both items are additive only. Pre-existing locked-edit and
--   unlocked-rebuild logic are untouched.
--
--   Live baseline at SQL/2026-05-13/CustomerPayment_Insert_live_baseline.sql.
-- =====================================================================

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
    @PreviousExtraDisposition NVARCHAR(50) = NULL,
    @NewExtraDisposition NVARCHAR(50) = NULL,
    @ExtraDispositionChanged BIT = NULL,
    @SelectedExtraDispositionAmount DECIMAL(18,2) = NULL,
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

        Locked-edit note (added 2026-05-11):
        - If the existing payment is locked (already deposited), we keep the
          header + the journal header, and only rebuild the child detail rows.
        - That preserves IsLocked and the bank-recon TxId link.
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
    DECLARE @DirectDocumentApplied DECIMAL(18,2) = 0;
    DECLARE @DirectCCFeeApplied DECIMAL(18,2) = 0;

    DECLARE @AsCredit BIT = 0;
    DECLARE @AsIncome BIT = 0;
    DECLARE @AsRefund BIT = 0;
    DECLARE @AsCCFee BIT = 0;
    DECLARE @ExtraAmount DECIMAL(18,2) = 0;
    DECLARE @SourceUseAsIncome DECIMAL(18,2) = 0;
    DECLARE @SourceUseRefundSelf DECIMAL(18,2) = 0;
    DECLARE @PrevAsIncome DECIMAL(18,2) = 0;
    DECLARE @PrevRefund DECIMAL(18,2) = 0;
    DECLARE @PrevCCFee DECIMAL(18,2) = 0;
    DECLARE @HasExplicitDispositionSwitch BIT = ISNULL(@ExtraDispositionChanged, 0);

    -- 2026-05-11 added: locked-edit path bookkeeping.
    DECLARE @IsLockedEdit BIT = 0;
    DECLARE @ExistingTxId BIGINT;
    DECLARE @PrevIsLocked BIT = 0;
    DECLARE @PrevPayeeId INT;
    DECLARE @PrevPaymentDate DATE;
    DECLARE @PrevPaymentMethod NVARCHAR(50);
    DECLARE @PrevPaymentAmount DECIMAL(18,2);
    DECLARE @PrevPaymentType NVARCHAR(100);
    DECLARE @PrevFromAccountId INT;

    -- 2026-05-13 added (Round 2 Item 2): preserve wipe-risk columns on unlocked rebuild.
    -- Captured from the existing row in the early-read block, re-applied
    -- in Phase 3's unlocked INSERT VALUES. For fresh inserts (@IsEdit = 0)
    -- these stay NULL, which is the correct default.
    DECLARE @PrevCardType NVARCHAR(50);
    DECLARE @PrevLast4 NVARCHAR(10);
    DECLARE @PrevAccountId1 INT;
    DECLARE @PrevAccountId2 INT;
    DECLARE @PrevAccountId3 INT;
    DECLARE @PrevAccountId4 INT;
    DECLARE @PrevAmount1 DECIMAL(18,2);
    DECLARE @PrevAmount2 DECIMAL(18,2);
    DECLARE @PrevAmount3 DECIMAL(18,2);
    DECLARE @PrevAmount4 DECIMAL(18,2);

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
    INSERT INTO @AcctTable(AccountCode) VALUES('@ICCF');
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

    -- 2026-05-11 added: early read of prior payment state for edits.
    --
    -- This sets up:
    --   @PaymentNumber, @CreatedAt,
    --   @PrevAsIncome, @PrevIsLocked, @PrevPayeeId, @PrevPaymentDate,
    --   @PrevPaymentMethod, @PrevPaymentAmount, @PrevPaymentType,
    --   @PrevFromAccountId,
    --   @PrevRefund, @PrevCCFee, @IsLockedEdit
    --
    -- These values are needed BEFORE Phase 1A's PaymentType branching and
    -- BEFORE Phase 1B's disposition processing. The locked-edit immutability
    -- guard immediately below this block uses @PrevPaymentType / @PrevFromAccountId
    -- so that a tampered request cannot change the posting mode of a deposited
    -- payment before Phase 1A consumes those fields. The locked-edit disposition
    -- override (after Phase 1B) uses @PrevAsIncome / @PrevRefund / @PrevCCFee.
    -- Reading them all here also means Phase 2A no longer needs its own header lookup.
    IF @CustomerPaymentId > 0
    BEGIN
        SELECT
            @PaymentNumber = PaymentNumber,
            @CreatedAt = CreatedAt,
            @PrevAsIncome = ISNULL(AsIncome, 0),
            @PrevIsLocked = ISNULL(IsLocked, 0),
            @PrevPayeeId = PayeeId,
            @PrevPaymentDate = PaymentDate,
            @PrevPaymentMethod = PaymentMethod,
            @PrevPaymentAmount = ISNULL(PaymentAmount, 0),
            @PrevPaymentType = PaymentType,
            @PrevFromAccountId = FromAccountId,
            -- 2026-05-13 added (Round 2 Item 2): capture wipe-risk columns
            -- so Phase 3's unlocked INSERT can preserve them on rebuild.
            @PrevCardType = CardType,
            @PrevLast4 = Last4,
            @PrevAccountId1 = AccountId1,
            @PrevAccountId2 = AccountId2,
            @PrevAccountId3 = AccountId3,
            @PrevAccountId4 = AccountId4,
            @PrevAmount1 = Amount1,
            @PrevAmount2 = Amount2,
            @PrevAmount3 = Amount3,
            @PrevAmount4 = Amount4
        FROM dbo.CustomerPayment
        WHERE CustomerPaymentId = @CustomerPaymentId;

        SET @IsLockedEdit = @PrevIsLocked;

        SELECT @PrevRefund = ISNULL(SUM(ISNULL(pd.PaymentApplied, 0)), 0)
        FROM dbo.CustomerPaymentDetail pd
        WHERE pd.CustomerPaymentId = @CustomerPaymentId
          AND pd.DetailRole = 'AsRefund'
          AND ISNULL(pd.SourcePaymentNumber, @PaymentNumber) = @PaymentNumber;

        SELECT @PrevCCFee = ISNULL(SUM(ISNULL(pd.PaymentApplied, 0)), 0)
        FROM dbo.CustomerPaymentDetail pd
        WHERE pd.CustomerPaymentId = @CustomerPaymentId
          AND pd.DetailRole = 'CCFee'
          AND ISNULL(pd.SourceCustomerPaymentId, 0) = 0;
    END;

    -- 2026-05-11 added (rev 3): locked-edit immutability guard.
    --
    -- Runs BEFORE Phase 1A because Phase 1A branches on @PaymentType to decide:
    --   - Bad Debt: sets @IsBadDebt = 1, nulls @PaymentMethod
    --   - Credit Apply: nulls @PaymentMethod
    --   - Customer Refund: sets @SourceDocType = 'Customer Refund', keeps @FromAccountId as bank/cash post account
    --   - Otherwise: sets @SourceDocType = 'Customer Payment', nulls @FromAccountId
    --
    -- A tampered caller could swap @PaymentType on a deposited payment
    -- (Customer Payment -> Bad Debt, for example) and swing the whole posting
    -- mode. The Phase 1B disposition override does not catch that because
    -- PaymentType is consumed earlier than disposition.
    --
    -- For Customer Refund, @FromAccountId is the bank-side post account, so
    -- it is also frozen here. Other payment types null @FromAccountId in
    -- Phase 1A regardless, so guarding it for those types is unnecessary.
    IF @IsLockedEdit = 1
    BEGIN
        IF @PayeeId <> @PrevPayeeId
           OR ISNULL(@PaymentDate, '1900-01-01') <> ISNULL(@PrevPaymentDate, '1900-01-01')
           OR ISNULL(@PaymentAmount, 0) <> @PrevPaymentAmount
           OR ISNULL(LTRIM(RTRIM(@PaymentMethod)), '') <> ISNULL(LTRIM(RTRIM(@PrevPaymentMethod)), '')
           OR ISNULL(LTRIM(RTRIM(@PaymentType)), '') <> ISNULL(LTRIM(RTRIM(@PrevPaymentType)), '')
        BEGIN
            THROW 50006, 'Deposited payment only allows reapply, notes, and reference updates.', 1;
        END;

        IF @PrevPaymentType = 'Customer Refund'
           AND ISNULL(@FromAccountId, 0) <> ISNULL(@PrevFromAccountId, 0)
        BEGIN
            THROW 50006, 'Deposited refund cannot change its source/bank account.', 1;
        END;
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
    -- - AsCCFee: use the whole leftover amount as card fee
    SELECT
        @AsCredit = AsCredit,
        @AsIncome = AsIncome,
        @AsRefund = AsRefund,
        @AsCCFee = AsCCMemo,
        @ExtraAmount = ExtraAmount
    FROM dbo.TempExtraPayment
    WHERE PayeeId = @PayeeId
      AND CustomerPaymentId = @CustomerPaymentId;

    -- When the user explicitly changed disposition in the current save flow,
    -- trust the save-request contract first instead of relying on temp-flag timing.
    IF @HasExplicitDispositionSwitch = 1 AND ISNULL(@NewExtraDisposition, '') <> ''
    BEGIN
        SET @AsCredit = 0;
        SET @AsIncome = 0;
        SET @AsRefund = 0;
        SET @AsCCFee = 0;
        SET @ExtraAmount = ISNULL(@SelectedExtraDispositionAmount, 0);

        IF @NewExtraDisposition = 'Credit'
            SET @AsCredit = 1;
        ELSE IF @NewExtraDisposition = 'Income'
            SET @AsIncome = 1;
        ELSE IF @NewExtraDisposition = 'Refund'
            SET @AsRefund = 1;
        ELSE IF @NewExtraDisposition = 'CCFee'
            SET @AsCCFee = 1;
    END;

    -- As CC Fee is only valid for credit-card payments.
    -- Enforce that rule here too so non-UI callers cannot persist an invalid disposition.
    IF @AsCCFee = 1 AND ISNULL(@PaymentMethod, '') <> 'CREDIT CARD'
    BEGIN
        THROW 50005, 'As CC Fee is only allowed when PaymentMethod is CREDIT CARD.', 1;
    END;

    -- Strict As CC Fee rule:
    -- if the user chose As CC Fee, the whole leftover amount becomes fee.
    -- That means:
    -- - no leftover is treated as credit/income/refund
    -- - @CCFee is driven from the explicit extra-disposition amount
    IF @AsCCFee = 1
    BEGIN
        SET @AsCredit = 0;
        SET @AsIncome = 0;
        SET @AsRefund = 0;
        SET @CCFee = @ExtraAmount;
    END;

    -- 2026-05-11 added: locked-edit disposition / CCFee force-override.
    --
    -- For a deposited (IsLocked = 1) payment, the only allowed change is the
    -- apportionment of apply across invoices/debit-memos. Disposition kind
    -- (AsCredit / AsIncome / AsRefund / AsCCFee) and CCFee must stay exactly
    -- as they were when the payment was first deposited.
    --
    -- The C# service guards only PayeeId / PaymentDate / PaymentMethod /
    -- PaymentAmount on the request, so a non-UI caller could still smuggle in
    -- altered disposition or CCFee values. This block makes the SP self-defending:
    -- it discards whatever Phase 1B read from TempExtraPayment / the request and
    -- restores the prior saved values from the existing detail rows. Phase 1D's
    -- CCFee helper, Phase 6's disposition rebuild, and Phase 9C/9D's journal
    -- posting then all run with the prior values, reproducing the original
    -- accounting unchanged.
    --
    -- AsCCFee vs AsCredit+CCFee note:
    --   The "AsCCFee = 1" disposition (whole leftover becomes fee) and the
    --   "AsCredit = 1 with separate @CCFee" case both leave the same CCFee
    --   detail rows + the same journal lines on disk. The override normalizes
    --   back to AsCredit + restored @CCFee, which produces identical output.
    IF @IsLockedEdit = 1
    BEGIN
        SET @AsCredit = 0;
        SET @AsIncome = 0;
        SET @AsRefund = 0;
        SET @AsCCFee = 0;
        SET @ExtraAmount = 0;
        SET @CCFee = @PrevCCFee;

        IF @PrevAsIncome > 0
        BEGIN
            SET @AsIncome = 1;
            SET @ExtraAmount = @PrevAsIncome;
        END
        ELSE IF @PrevRefund > 0
        BEGIN
            SET @AsRefund = 1;
            SET @ExtraAmount = @PrevRefund;
        END
        ELSE
        BEGIN
            SET @AsCredit = 1;
        END;

        -- Mark disposition as explicitly settled so Phase 2A's prior-disposition
        -- fallback does not run and re-mutate these values.
        SET @HasExplicitDispositionSwitch = 1;
    END;

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
    --   (unless the payment is locked, in which case the delete is replaced by
    --    a child-rows-only reset, preserving IsLocked and the bank-recon TxId)
    --
    -- If this is a new payment:
    -- - take the next payment number from the sequence
    IF @CustomerPaymentId > 0
    BEGIN
        SET @IsEdit = 1;
        SET @UpdatedAt = GETUTCDATE();

        -- @PaymentNumber, @CreatedAt, @PrevAsIncome, @IsLockedEdit, @PrevPayeeId,
        -- @PrevPaymentDate, @PrevPaymentMethod, @PrevPaymentAmount, @PrevPaymentType,
        -- @PrevFromAccountId, @PrevRefund, @PrevCCFee were all populated by the
        -- early-read block above. The locked-edit immutability guard already ran
        -- before Phase 1A and rejected any change to the immutable header fields.

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

        -- Preserve prior extra-disposition intent only when the user did NOT
        -- explicitly switch disposition in the current edit flow.
        --
        -- Replacement rule:
        -- - explicit switch = trust the current save contract only
        -- - untouched edit save = allow fallback to prior intent
        --
        -- @PrevRefund and @PrevCCFee were populated by the early-read block.
        -- For locked-edit, @HasExplicitDispositionSwitch was force-set to 1 by
        -- the Phase 1B override block, so this fallback does not fire and the
        -- forced disposition values are preserved.
        IF @HasExplicitDispositionSwitch = 0
           AND @ExtraAmount = 0
           AND @AsIncome = 0
           AND @AsRefund = 0
           AND @AsCCFee = 0
           AND (@PrevAsIncome > 0 OR @PrevRefund > 0 OR @PrevCCFee > 0)
        BEGIN
            SET @ExtraAmount =
                CASE
                    WHEN @PrevRefund > 0 THEN @PrevRefund
                    WHEN @PrevCCFee > 0 THEN @PrevCCFee
                    ELSE @PrevAsIncome
                END;
            SET @AsRefund = CASE WHEN @PrevRefund > 0 THEN 1 ELSE 0 END;
            SET @AsCCFee = CASE WHEN @PrevRefund = 0 AND @PrevCCFee > 0 THEN 1 ELSE 0 END;
            SET @AsIncome = CASE WHEN @PrevRefund > 0 OR @PrevCCFee > 0 THEN 0 ELSE 1 END;
            SET @AsCredit = 0;

            IF @AsCCFee = 1
                SET @CCFee = @ExtraAmount;
        END;

        -- 2026-05-11 added: branch on lock state.
        --
        -- Locked path:
        --   - DO NOT delete the CustomerPayment header (preserves IsLocked).
        --   - DO NOT delete the TransactionJournal header (preserves bank-recon TxId).
        --   - Replicate what the delete trigger normally does for the apply side:
        --       a. revert the existing sales-side application via CustomerPayment_UpdateSales
        --       b. drop the auto-generated CCFee Sales rows so Phase 1D's helper rebuild is clean
        --       c. delete CustomerPaymentDetail (children of the kept header)
        --       d. delete TransactionJournalDetail under the existing TxId (children of the kept journal header)
        --
        -- Unlocked path (existing behavior):
        --   - Delete the header. The delete trigger TRG_Delete_CustomerPaymentTx handles
        --     sales reversal, CCFee Sales cleanup, and TransactionJournal cleanup as a side-effect.
        IF @IsLockedEdit = 1
        BEGIN
            -- (a) Revert existing sales-side application before dropping detail rows.
            -- This matches what TRG_Delete_CustomerPaymentTx does for the unlocked path.
            EXEC dbo.CustomerPayment_UpdateSales @CustomerPaymentId, 1;

            -- (b) Remove auto-generated CCFee Sales rows so Phase 1D's helper rebuild is clean.
            DELETE FROM dbo.Sales
            WHERE SalesId IN (
                SELECT SalesId
                FROM dbo.CustomerPaymentDetail
                WHERE CustomerPaymentId = @CustomerPaymentId
                  AND IsCCFee = 1
            );

            -- (c) Drop the apply rows. The header itself is preserved.
            DELETE FROM dbo.CustomerPaymentDetail
            WHERE CustomerPaymentId = @CustomerPaymentId;

            -- (d) Look up the existing journal header and drop its detail rows.
            -- Reusing the TxId is the whole point: bank-recon / deposit allocations
            -- reference TransactionJournal by TxId, so this row must not change identity.
            SELECT @ExistingTxId = TxId
            FROM dbo.TransactionJournal
            WHERE SourceDocType IN ('Customer Payment', 'Customer Refund')
              AND SourceDocNumber = @PaymentNumber;

            IF @ExistingTxId IS NULL
                THROW 50007, 'Locked payment is missing its TransactionJournal header. Cannot reapply.', 1;

            DELETE FROM dbo.TransactionJournalDetail
            WHERE TxId = @ExistingTxId;
        END
        ELSE
        BEGIN
            -- Delete the old header now. The delete trigger cleans dependent committed rows.
            -- After this point the procedure rebuilds the payment from staged temp truth.
            DELETE FROM dbo.CustomerPayment WHERE CustomerPaymentId = @CustomerPaymentId;
        END;
    END
    ELSE
        SET @PaymentNumber = NEXT VALUE FOR dbo.Seq_CustomerPaymentNumber;

    -- Phase 3. Insert (or preserve) the CustomerPayment header row.
    --
    -- Header totals start at zero here in the unlocked/new path.
    -- They are recalculated after committed detail rows and G/L rows are created.
    --
    -- 2026-05-11 added: locked-edit reuses the existing header. The eventual
    -- header refresh in Phase 10A is restricted to PaymentApplied / UnappliedAmount /
    -- Notes / ReferenceId / UpdatedAt so the immutable fields stay as saved.
    IF @IsLockedEdit = 1
    BEGIN
        -- Reuse existing header. @CustomerPaymentId already references the kept row.
        -- No INSERT here. Phase 10A refreshes only the recomputed apply fields.
        SET @CustomerPaymentId = @CustomerPaymentId; -- explicit no-op for readability
    END
    ELSE
    BEGIN
        -- 2026-05-13 (Round 2 Item 2): preserve wipe-risk columns from
        -- @Prev* on edit-rebuild. For new inserts (@IsEdit = 0) the
        -- @Prev* values stay NULL, which matches the fresh-insert defaults.
        INSERT INTO dbo.CustomerPayment
        (
            PaymentNumber, PaymentType, PayeeId, PaymentDate, PaymentMethod, FromAccountId,
            ReferenceId, PaymentAmount, Notes, PaymentApplied, UnappliedAmount, IsBadDebt,
            CardType, Last4,
            AccountId1, AccountId2, AccountId3, AccountId4,
            Amount1, Amount2, Amount3, Amount4,
            CreatedAt, UpdatedAt
        )
        VALUES
        (
            @PaymentNumber, @PaymentType, @PayeeId, @PaymentDate, @PaymentMethod, @FromAccountId,
            @ReferenceId, @PaymentAmount, @Notes, 0, 0, @IsBadDebt,
            @PrevCardType, @PrevLast4,
            @PrevAccountId1, @PrevAccountId2, @PrevAccountId3, @PrevAccountId4,
            @PrevAmount1, @PrevAmount2, @PrevAmount3, @PrevAmount4,
            @CreatedAt, @UpdatedAt
        );

        SELECT @CustomerPaymentId = SCOPE_IDENTITY();
    END;

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

    -- Header applied amount should mean only real document application.
    -- In plain words:
    -- - invoice rows count
    -- - debit memo rows count
    -- - CCFee rows do NOT count
    --
    -- Why:
    -- CCFee is a separate fee carved out of the gross receipt.
    -- It is not customer AR application and it is not reusable customer credit.
    SELECT @CashApplied = ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId
      AND DetailRole IN ('Invoice', 'DebitMemo')
      AND ISNULL(SourceCustomerPaymentId, 0) = 0;

    SET @CashApplied = @CashApplied - @CreditMemoUsed;

    -- For AR posting, use only the real document application amount.
    -- This is the invoice/debit-memo portion of the receipt before any fee posting.
    SELECT @DirectDocumentApplied = ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId
      AND DetailRole IN ('Invoice', 'DebitMemo')
      AND ISNULL(SourceCustomerPaymentId, 0) = 0;

    -- Track the direct fee portion separately.
    -- This amount is consumed by the payment, but it is not AR application
    -- and it must not remain as reusable customer credit.
    SELECT @DirectCCFeeApplied = ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId
      AND DetailRole = 'CCFee'
      AND ISNULL(SourceCustomerPaymentId, 0) = 0;

    SELECT @TotalDiscountApplied = ISNULL(SUM(ISNULL(DiscountApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId;

    -- Prior source-credit usage should follow the same rule.
    -- Only invoice/debit-memo application funded by prior credit counts here.
    -- CCFee does not belong in reusable-credit math.
    SELECT @PriorUnappliedUsed = ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
    FROM dbo.CustomerPaymentDetail
    WHERE CustomerPaymentId = @CustomerPaymentId
      AND DetailRole IN ('Invoice', 'DebitMemo')
      AND ISNULL(SourceCustomerPaymentId, 0) <> 0;

    -- AR posting rule in plain words:
    -- - gross cash stays on UF
    -- - fee stays on ICCF
    -- - AR gets only real customer document settlement plus discount
    -- - AsIncome does NOT reduce AR here because it already gets its own
    --   dedicated IOT posting line later in the journal build
    -- - AsCredit DOES increase AR here because unapplied customer credit still
    --   belongs on AR even when it is not yet applied to a document
    -- - AsRefund ALSO increases AR here because the initial receipt still
    --   creates customer credit before the later AR/CRP reserve reclass
    -- 2026-05-04 historical live AR basis kept for reviewer comparison:
    -- SET @AR = @DirectDocumentApplied + @TotalDiscountApplied;
    --
    -- Current rule:
    -- direct document settlement funded by reused credit memo should not be
    -- credited to AR again as new incoming value on this payment.
    --
    -- Credit memo usage is already existing customer credit. So the AR posting
    -- basis here must exclude the credit memo-funded portion and keep only the
    -- net settlement funded by this payment's own incoming amount plus discount.
    SET @AR = @DirectDocumentApplied + @TotalDiscountApplied - @CreditMemoUsed;

    IF @IsBadDebt = 1
        SET @AR = @CashApplied + @TotalDiscountApplied;

    IF @AsCredit = 1
        SET @AR = @AR + @ExtraAmount;

    IF @AsRefund = 1
        SET @AR = @AR + @ExtraAmount;

    -- 2026-05-13 added (Round 2 Item 1): defensive over-application invariant.
    --
    -- The locked-edit path pins disposition + @CCFee to prior saved values,
    -- but the apply totals (invoice/debit-memo apportionment) still come
    -- from the front-end via TempCustomerPayment. A buggy or tampered caller
    -- could submit apply rows that exceed @PaymentAmount - prior_disposition -
    -- prior_CCFee. Previously the SP over-allocated AR silently and left
    -- the header UnappliedAmount inconsistent.
    --
    -- Invariant:
    --   expected = @DirectDocumentApplied
    --            + @DirectCCFeeApplied
    --            + (@ExtraAmount if @AsIncome=1 or @AsRefund=1, else 0)
    --            - @CreditMemoUsed
    --
    -- Carve-outs:
    -- - @AsCredit = 1: leftover absorbs into unapplied credit with no detail
    --   row, so totals can't be reconciled against @PaymentAmount.
    -- - @IsBadDebt = 1: balances differently (@AR = @CashApplied +
    --   @TotalDiscountApplied, offset by @EBAD, not against @PaymentAmount).
    --
    -- DECIMAL(18,2) is exact arithmetic, so use `<>` (no tolerance band).
    IF @AsCredit = 0 AND @IsBadDebt = 0
    BEGIN
        DECLARE @ExpectedApplied DECIMAL(18,2) =
            @DirectDocumentApplied
            + @DirectCCFeeApplied
            + CASE WHEN @AsIncome = 1 OR @AsRefund = 1 THEN @ExtraAmount ELSE 0 END
            - @CreditMemoUsed;

        IF @ExpectedApplied <> @PaymentAmount
            THROW 50012, 'Customer payment over-application: apply rows exceed available payment amount after disposition and CCFee.', 1;
    END;

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
    DECLARE @PostICCF DECIMAL(18,2) = ISNULL((
        SELECT SUM(ISNULL(pd.PaymentApplied, 0))
        FROM dbo.CustomerPaymentDetail pd
        WHERE pd.CustomerPaymentId = @CustomerPaymentId
          AND pd.DetailRole = 'CCFee'
          AND ISNULL(pd.SourceCustomerPaymentId, 0) = 0
    ), 0);
    -- 2026-05-04 historical logic kept for reviewer comparison:
    -- Reuse of prior unapplied payments or credit memos creates no new G/L.
    -- Those source documents already created their own accounting when they were created.
    -- DECLARE @PostIOTReuse DECIMAL(18,2) = 0;
    --
    -- New balancing rule:
    -- AR is posted from the full settled target-document amount.
    -- When part of that settlement was funded by reused customer credit,
    -- the balancing side must also recognize that reused source value too.
    --
    -- 2026-05-04 attempted balancing patch kept for reviewer comparison:
    -- Current scoped rule:
    -- only credit memo reuse needs this balancing line here.
    -- Prior unapplied payment reuse is already excluded from the AR-side amount,
    -- so adding it here would overcorrect and create a new imbalance.
    -- DECLARE @PostIOTReuse DECIMAL(18,2) = @CreditMemoUsed;
    --
    -- Reuse posting is disabled again here.
    -- The correct fix belongs in the AR posting basis, not in an OTHER INCOME line.
    DECLARE @PostIOTReuse DECIMAL(18,2) = 0;
    DECLARE @PostIOTAsIncome DECIMAL(18,2) = @ExtraAmount;

    -- Phase 8. Insert or reuse the TransactionJournal header.
    --
    -- New / unlocked-edit:
    --   - Insert a fresh journal header. Its TxId becomes @TxId.
    --
    -- Locked-edit (2026-05-11 added):
    --   - Reuse @ExistingTxId so the bank-recon / deposit FK link is preserved.
    --   - Refresh only the descriptive Notes field. TxDate / SourceDocType /
    --     SourceDocNumber / SourceDocOrder are derived from immutable payment fields.
    IF @IsLockedEdit = 1
    BEGIN
        SET @TxId = @ExistingTxId;

        UPDATE dbo.TransactionJournal
        SET Notes = @Notes
        WHERE TxId = @TxId;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.TransactionJournal
        (
            TxDate, TxTime, SourceDocOrder, SourceDocType, SourceDocNumber, Notes
        )
        VALUES
        (
            @PaymentDate, GETUTCDATE(), @SourceDocOrder, @SourceDocType, @PaymentNumber, @Notes
        );

        SELECT @TxId = SCOPE_IDENTITY();
    END;

    -- Phase 9. Insert TransactionJournalDetail rows.
    --
    -- These lines are the actual accounting result of the save.
    --
    -- Sign convention reminder for every account line in this section:
    -- - first set @Amount to the business increase/decrease for that account
    -- - then call Fn_Adjust_CrDeAmount
    -- - the function converts that increase/decrease into debit/credit-side
    --   storage through CrDeAmount
    --
    -- In other words:
    -- - Amount = source of truth for INC / DEC
    -- - CrDeAmount = derived debit / credit storage

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

        -- Post the fee as its own dedicated credit line.
        -- This keeps fee out of AR application and out of reusable customer credit.
        IF @PostICCF <> 0
        BEGIN
            /*
                Sign convention reminder:

                Amount is the source of truth for account increase/decrease.
                Fn_Adjust_CrDeAmount is responsible for converting that business
                increase/decrease into debit-side or credit-side storage.

                So for credit-card fee income:
                - income increasing means Amount must be positive
                - the function will then derive the credit-side CrDeAmount
            */
            SET @Amount = @PostICCF;
            SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@ICCF';
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

        -- 19C. Reuse posting is intentionally disabled here.
        --
        -- 2026-05-04 historical comment kept for reviewer comparison:
        -- - prior unapplied reuse = no new G/L
        -- - credit memo reuse = no new G/L
        --
        -- 2026-05-04 attempted patch kept for reviewer comparison:
        -- if AR is credited for document settlement funded by reused customer credit,
        -- the balancing side must also recognize that reused source value here.
        --
        -- That approach was incorrect because it created an OTHER INCOME credit
        -- for credit memo reuse. The next phase fixes the AR-side basis instead.
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
    -- 2026-05-11 added: the locked-edit path additionally refreshes Notes /
    -- ReferenceId / UpdatedAt so the user's allowed in-place changes persist.
    -- It still does NOT touch PayeeId / PaymentDate / PaymentMethod /
    -- PaymentAmount / IsLocked, which the immutability guard already verified
    -- are unchanged.
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

    IF @IsLockedEdit = 1
    BEGIN
        -- Locked-edit refresh:
        -- only the recomputed apply totals + the user's allowed edits.
        UPDATE dbo.CustomerPayment
        SET
            PaymentApplied = (
                SELECT ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
                FROM dbo.CustomerPaymentDetail
                WHERE CustomerPaymentId = @CustomerPaymentId
                  AND DetailRole IN ('Invoice', 'DebitMemo')
                  AND ISNULL(SourceCustomerPaymentId, 0) = 0
            ) - @CreditMemoUsed,
            UnappliedAmount = @PaymentAmount - (
                SELECT ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
                FROM dbo.CustomerPaymentDetail
                WHERE CustomerPaymentId = @CustomerPaymentId
                  AND DetailRole IN ('Invoice', 'DebitMemo')
                  AND ISNULL(SourceCustomerPaymentId, 0) = 0
            ) - @DirectCCFeeApplied + @CreditMemoUsed - (ISNULL(AsIncome, 0) - @SourceUseAsIncome) - @SourceUseRefundSelf - @ConsumedByOthers,
            Notes = @Notes,
            ReferenceId = @ReferenceId,
            UpdatedAt = @UpdatedAt
        WHERE CustomerPaymentId = @CustomerPaymentId;
    END
    ELSE
    BEGIN
        -- Current payment header refresh.
        --
        -- Keep the rule simple:
        -- - PaymentApplied = only invoice/debit-memo application
        -- - UnappliedAmount = reusable customer credit only
        -- - CCFee is consumed by the receipt, so subtract it from reusable leftover
        -- - CCFee still does NOT count as PaymentApplied
        UPDATE dbo.CustomerPayment
        SET
            PaymentApplied = (
                SELECT ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
                FROM dbo.CustomerPaymentDetail
                WHERE CustomerPaymentId = @CustomerPaymentId
                  AND DetailRole IN ('Invoice', 'DebitMemo')
                  AND ISNULL(SourceCustomerPaymentId, 0) = 0
            ) - @CreditMemoUsed,
            UnappliedAmount = @PaymentAmount - (
                SELECT ISNULL(SUM(ISNULL(PaymentApplied, 0)), 0)
                FROM dbo.CustomerPaymentDetail
                WHERE CustomerPaymentId = @CustomerPaymentId
                  AND DetailRole IN ('Invoice', 'DebitMemo')
                  AND ISNULL(SourceCustomerPaymentId, 0) = 0
            ) - @DirectCCFeeApplied + @CreditMemoUsed - (ISNULL(AsIncome, 0) - @SourceUseAsIncome) - @SourceUseRefundSelf - @ConsumedByOthers
        WHERE CustomerPaymentId = @CustomerPaymentId;
    END;

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
            -- Source-payment header refresh uses the same rule as the current payment:
            -- count only invoice/debit-memo rows as PaymentApplied,
            -- but subtract CCFee from reusable leftover credit.
            OwnCashApplied = ISNULL((
                SELECT SUM(ISNULL(pd.PaymentApplied, 0))
                FROM dbo.CustomerPaymentDetail pd
                WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
                  AND pd.DetailRole IN ('Invoice', 'DebitMemo')
                  AND ISNULL(pd.SourceCustomerPaymentId, 0) = 0
            ), 0),
            DirectCCFeeApplied = ISNULL((
                SELECT SUM(ISNULL(pd.PaymentApplied, 0))
                FROM dbo.CustomerPaymentDetail pd
                WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
                  AND pd.DetailRole = 'CCFee'
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
        UnappliedAmount = sh.PaymentAmount - sh.OwnCashApplied - sh.DirectCCFeeApplied + sh.CreditMemoUsed - (sh.AsIncome - sh.SourceUseAsIncome) - sh.SourceUseRefundSelf - sh.ConsumedByOthers
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

