
-- =============================================================================================
-- BankFeed_CreateDeposit
--   Creates a Deposit from a pending money-in bank feed row covering the selected undeposited
--   customer payments, posts the journal, registers what was generated, and matches the bank
--   row. Phase 2a: the payments already exist; this creates ONE document, the Deposit.
--   Plan: plan/bank-feed-create-phase-2-open-invoice.md  (Slice 3, decisions D3/D4/D7/D8)
--
-- One procedure owns the whole flow so there is ONE transaction boundary and ONE error path
-- (same shape as BankFeed_CreateVendorPayment). The C# service serialises the selected
-- payment ids to JSON and calls this once.
--
-- Steps: validate -> clear staging residue -> seed TempTransferFund -> Deposit_Insert ->
--        locate journal -> insert BankFeedSource -> BankFeed_MatchTx.
--
-- Amount semantics, from Deposit_Insert's own posting (verified live 2026-08-06):
--     @UF   decreases by SUM(DepositAmount)
--     bank  increases by @TransferAmount
--     fee/rounding/cashback accounts increase by their amounts
--   so the balanced journal REQUIRES
--     @TransferAmount = SUM(DepositAmount) - CCFee - Rounding - Cashback
--   i.e. the difference REDUCES what reaches the bank (a processor fee is withheld before
--   the money lands). The bank row IS @TransferAmount; the difference the user allocates is
--   SUM(selected payments) - bank amount, and it must be >= 0. A bank row LARGER than the
--   selected payments has no posting home here (that would be interest or an unrecorded
--   payment) and is refused.
--
-- A deposit takes each payment's FULL PaymentAmount - no per-payment amount is accepted.
-- Verified 2026-08-06: zero partial rows in 23,926 live TransferFundDetail rows.
--
-- Not accepted as parameters, by design:
--   @TFDate               - always the bank row's PostedDate (D9)
--   @DifferenceResolution - it IS @DifferenceKind here; stored verbatim (D7)
--
-- TempTransferFund is screen residue, not a draft store: Deposit_Inject DELETEs and reseeds
-- it per EmpId on every manual-screen load, with IsApplied=0 candidates and IsApplied=1
-- selections. Only IsApplied=1 rows carry user intent, so only they block (50413); the
-- IsApplied=0 residue is cleared here exactly as Deposit_Inject itself would.
--
-- Error numbers 50401-50421. BankFeed_MatchTx owns 50001+; Phase 1 create 50101+; Phase 1
-- lookup 50201+; Phase 1 reverse 50301+; Phase 2 lookup 50501+.
-- =============================================================================================

CREATE   PROCEDURE [dbo].[BankFeed_CreateDeposit]   -- EXEC dbo.BankFeed_CreateDeposit @BankFeedTransactionId=1, @PaymentIdsJson='[1,2]', @DifferenceKind='None', @DifferenceAccountId=NULL, @DifferenceMemo=NULL, @EmpId=1, @NewTFId=NULL
    @BankFeedTransactionId BIGINT,
    @PaymentIdsJson        NVARCHAR(MAX),
    @DifferenceKind        VARCHAR(20)   = 'None',   -- 'None' | 'BankFee' | 'Rounding' | 'Account'
    @DifferenceAccountId   INT           = NULL,     -- required when @DifferenceKind = 'Account'
    @DifferenceMemo        NVARCHAR(500) = NULL,     -- required when @DifferenceKind <> 'None'
    @EmpId                 INT,
    @NewTFId               INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ---------------------------------------------------------------------------------------
    -- A. Parse the ids. Touches no database state, so it sits outside the transaction.
    ---------------------------------------------------------------------------------------
    IF @PaymentIdsJson IS NULL OR ISJSON(@PaymentIdsJson) <> 1
        THROW 50406, 'No payments were selected for this deposit.', 1;

    SELECT CAST([value] AS INT) AS CustomerPaymentId
    INTO #Payments
    FROM OPENJSON(@PaymentIdsJson);

    IF NOT EXISTS (SELECT 1 FROM #Payments)
        THROW 50406, 'No payments were selected for this deposit.', 1;

    ---------------------------------------------------------------------------------------
    -- The transaction opens BEFORE validation on purpose: the UPDLOCK below is what stops
    -- two users clicking Create on the same bank row from both passing the "no Active
    -- BankFeedSource" check. Validation still runs before any write, so a THROW here rolls
    -- back nothing. (Same reasoning as BankFeed_CreateVendorPayment.)
    ---------------------------------------------------------------------------------------
    BEGIN TRAN;
    BEGIN TRY

        -----------------------------------------------------------------------------------
        -- B. Load the bank feed row and the GL account it maps to
        -----------------------------------------------------------------------------------
        DECLARE @Status         VARCHAR(20),
                @PostedDate     DATE,
                @BankAmount     DECIMAL(18,2),
                @Description    NVARCHAR(500),
                @BankAccountId  INT,
                @IsAccountDebit BIT;

        SELECT @Status         = bft.[Status],
               @PostedDate     = bft.PostedDate,
               @BankAmount     = bft.Amount,
               @Description    = bft.[Description],
               @BankAccountId  = bfa.AccountId,
               @IsAccountDebit = a.IsAccountDebit
        FROM dbo.BankFeedTransaction AS bft WITH (UPDLOCK, HOLDLOCK)
        LEFT JOIN dbo.BankFeedAccount AS bfa
            ON bfa.BankFeedAccountId = bft.BankFeedAccountId
        LEFT JOIN dbo.Account AS a
            ON a.AccountId = bfa.AccountId
        WHERE bft.BankFeedTransactionId = @BankFeedTransactionId;

        -----------------------------------------------------------------------------------
        -- C. Validate. Everything THROWs; nothing has been written yet.
        -----------------------------------------------------------------------------------
        IF @Status IS NULL
            THROW 50401, 'Bank feed transaction not found.', 1;

        IF @Status <> 'Pending'
            THROW 50402, 'Only pending bank feed transactions can create a deposit.', 1;

        IF @BankAmount <= 0
            THROW 50403, 'Only money-in bank feed transactions can create a deposit.', 1;

        IF @BankAccountId IS NULL
            THROW 50404, 'This bank feed row is not mapped to a GL account.', 1;

        -- The deposit's bank line posts as +TransferAmount only for a debit (asset) account.
        -- On a credit account the sign flips and BankFeed_MatchTx would reject the amount
        -- with a much less helpful message, so catch the misconfiguration here.
        IF @IsAccountDebit <> 1
            THROW 50414, 'The GL account mapped to this bank feed is not a debit account.', 1;

        IF EXISTS (SELECT 1 FROM dbo.BankFeedSource
                   WHERE BankFeedTransactionId = @BankFeedTransactionId
                     AND [Status] = 'Active')
            THROW 50405, 'This bank feed row already has a transaction created by Bank Feed. Reverse it first.', 1;

        IF EXISTS (SELECT 1 FROM #Payments GROUP BY CustomerPaymentId HAVING COUNT(*) > 1)
            THROW 50409, 'The same payment was selected more than once.', 1;

        IF EXISTS (SELECT 1
                   FROM #Payments AS s
                   LEFT JOIN dbo.CustomerPayment AS cp ON cp.CustomerPaymentId = s.CustomerPaymentId
                   WHERE cp.CustomerPaymentId IS NULL)
            THROW 50407, 'One or more selected payments do not exist.', 1;

        -- IsLocked = 1 means already deposited (set by Deposit_Insert, reset by
        -- TRG_Delete_TFTx). The PaymentType list is Deposit_Inject's own candidate rule -
        -- Bank Feed must not deposit what the manual screen would not offer.
        IF EXISTS (SELECT 1
                   FROM #Payments AS s
                   JOIN dbo.CustomerPayment AS cp ON cp.CustomerPaymentId = s.CustomerPaymentId
                   WHERE cp.IsLocked = 1
                      OR cp.PaymentType NOT IN ('Actual Payment', 'Vendor Refund'))
            THROW 50408, 'One or more selected payments are already deposited or cannot be deposited.', 1;

        IF @DifferenceKind IS NULL
           OR @DifferenceKind NOT IN ('None', 'BankFee', 'Rounding', 'Account')
            THROW 50416, 'Unsupported difference kind.', 1;

        -----------------------------------------------------------------------------------
        -- C1. The money invariant. Difference = selected total - bank amount, and it is
        --     what Deposit_Insert will post to the fee/rounding/cashback account (see the
        --     amount-semantics note in the header).
        -----------------------------------------------------------------------------------
        DECLARE @SelectedTotal DECIMAL(18,2),
                @Difference    DECIMAL(18,2);

        SELECT @SelectedTotal = SUM(cp.PaymentAmount)
        FROM #Payments AS s
        JOIN dbo.CustomerPayment AS cp ON cp.CustomerPaymentId = s.CustomerPaymentId;

        SET @Difference = @SelectedTotal - @BankAmount;

        IF @Difference < 0
            THROW 50415, 'The bank amount exceeds the selected payments. Select more payments; extra money in the bank row cannot be allocated here.', 1;

        IF (@DifferenceKind = 'None' AND @Difference <> 0)
           OR (@DifferenceKind <> 'None' AND @Difference = 0)
            THROW 50410, 'The selected payments minus the allocated difference must equal the bank amount.', 1;

        IF @DifferenceKind = 'Account' AND @DifferenceAccountId IS NULL
            THROW 50411, 'Please choose the account for the difference.', 1;

        IF @DifferenceKind = 'Account'
           AND NOT EXISTS (SELECT 1 FROM dbo.Account WHERE AccountId = @DifferenceAccountId)
            THROW 50417, 'The selected difference account does not exist.', 1;

        -- Posting the difference to the bank account would net against the bank line and
        -- vanish; posting it to @UF would corrupt the undeposited-funds clearing balance
        -- that TransferFundDetail rows account for.
        IF @DifferenceKind = 'Account'
           AND (@DifferenceAccountId = @BankAccountId
                OR EXISTS (SELECT 1 FROM dbo.Account
                           WHERE AccountId = @DifferenceAccountId AND AccountCode = '@UF'))
            THROW 50418, 'The difference cannot post to the bank account or to Undeposited Funds.', 1;

        IF @DifferenceKind <> 'None'
           AND (@DifferenceMemo IS NULL OR LTRIM(RTRIM(@DifferenceMemo)) = '')
            THROW 50412, 'A memo is required when a difference is allocated.', 1;

        -- Only IsApplied=1 rows are a live manual deposit selection and block. IsApplied=0
        -- rows are abandoned screen residue (797 such rows live at the time of writing) and
        -- are cleared below, exactly as Deposit_Inject itself does on every load.
        IF EXISTS (SELECT 1 FROM dbo.TempTransferFund
                   WHERE EmpId = @EmpId AND IsApplied = 1)
            THROW 50413, 'You have an unsaved deposit in progress on the Deposit screen. Finish or close it first.', 1;

        -----------------------------------------------------------------------------------
        -- D. Clear staging residue, then seed the rows Deposit_Insert reads
        --    (EmpId + TFId=0 + IsApplied=1). Deposit_Insert deletes ALL TempTransferFund
        --    rows for @EmpId on success - do not delete them again after step E.
        -----------------------------------------------------------------------------------
        DELETE FROM dbo.TempTransferFund WHERE EmpId = @EmpId;

        INSERT INTO dbo.TempTransferFund
            (EmpId, TFId, CustomerPaymentId, DepositAmount, Notes, IsApplied)
        SELECT @EmpId, 0, cp.CustomerPaymentId, cp.PaymentAmount, NULL, 1
        FROM #Payments AS s
        JOIN dbo.CustomerPayment AS cp ON cp.CustomerPaymentId = s.CustomerPaymentId;

        -----------------------------------------------------------------------------------
        -- E. Create the deposit and post the journal. @TransferAmount is the bank amount by
        --    construction (C1), so the journal's bank line equals the bank feed row and
        --    BankFeed_MatchTx's sum check holds. Deposit_Insert calls Recalc_AfterInsert
        --    itself (manual-screen behaviour, left as is) and cleans up TempTransferFund.
        -----------------------------------------------------------------------------------
        DECLARE @CashbackAccountId INT           = NULL,
                @CashbackAmount    DECIMAL(18,2) = 0,
                @CCFeeAmount       DECIMAL(18,2) = 0,
                @RoundingOff       DECIMAL(18,2) = 0;

        IF @DifferenceKind = 'BankFee'  SET @CCFeeAmount = @Difference;
        IF @DifferenceKind = 'Rounding' SET @RoundingOff = @Difference;
        IF @DifferenceKind = 'Account'
        BEGIN
            SET @CashbackAmount    = @Difference;
            SET @CashbackAccountId = @DifferenceAccountId;
        END

        EXEC dbo.Deposit_Insert
            @TFId              = 0,
            @TFDate            = @PostedDate,
            @ToAccountId       = @BankAccountId,
            @TransferAmount    = @BankAmount,
            @CashbackAccountId = @CashbackAccountId,
            @CashbackAmount    = @CashbackAmount,
            @CCFeeAmount       = @CCFeeAmount,
            @RoundingOff       = @RoundingOff,
            @EmpId             = @EmpId,
            @NewTFId           = @NewTFId OUTPUT;

        IF @NewTFId IS NULL OR @NewTFId <= 0
            THROW 50419, 'The deposit could not be created.', 1;

        -----------------------------------------------------------------------------------
        -- F. Locate the journal it posted. Deposit_Insert returns only @NewTFId, so read
        --    TFNumber back and use (SourceDocType, SourceDocNumber) - the same handle
        --    TRG_Delete_TFTx deletes by. Assert a single row rather than taking TOP 1:
        --    this is money, and if the assumption ever breaks it should stop, not guess.
        -----------------------------------------------------------------------------------
        DECLARE @TFNumber   INT,
                @TxId       BIGINT,
                @TxDetailId BIGINT,
                @RowCheck   INT;

        SELECT @TFNumber = TFNumber
        FROM dbo.TransferFund
        WHERE TFId = @NewTFId;

        SELECT @RowCheck = COUNT(*), @TxId = MIN(TxId)
        FROM dbo.TransactionJournal
        WHERE SourceDocType   = 'Deposit'
          AND SourceDocNumber = @TFNumber;

        IF @RowCheck <> 1
            THROW 50420, 'Could not identify the journal transaction for the new deposit.', 1;

        SELECT @RowCheck = COUNT(*), @TxDetailId = MIN(TxDetailId)
        FROM dbo.TransactionJournalDetail
        WHERE TxId = @TxId
          AND AccountId = @BankAccountId;

        IF @RowCheck <> 1
            THROW 50421, 'Could not identify the bank line of the new journal transaction.', 1;

        -----------------------------------------------------------------------------------
        -- G. Register what Bank Feed generated, so it can be traced and reversed.
        --    OriginalBankAmount keeps the SIGNED bank amount (positive for money in).
        --    DifferenceResolution stores the kind verbatim - unlike Phase 1 there is
        --    nothing to derive (D7); DifferenceAccountId is only set for 'Account'.
        -----------------------------------------------------------------------------------
        INSERT INTO dbo.BankFeedSource
            (BankFeedTransactionId, SourceDocType, SourceDocId, TxId,
             [Mode], [Status], OriginalBankAmount, AppliedAmount, DifferenceAmount,
             DifferenceResolution, DifferenceAccountId, DifferenceMemo, CreatedAt, CreatedBy)
        VALUES
            (@BankFeedTransactionId, 'Deposit', @NewTFId, @TxId,
             'DepositPayments', 'Active', @BankAmount, @SelectedTotal, @Difference,
             @DifferenceKind, @DifferenceAccountId, @DifferenceMemo, SYSUTCDATETIME(), @EmpId);

        -----------------------------------------------------------------------------------
        -- H. Match through the existing path, so create and manual match cannot drift.
        --    It re-validates account / amount / not-already-matched / not-locked, sets the
        --    journal BankDate, and moves the header to Matched.
        -----------------------------------------------------------------------------------
        DECLARE @MatchItemsJson NVARCHAR(MAX) =
            (SELECT @TxId AS TxId, @TxDetailId AS TxDetailId FOR JSON PATH);

        EXEC dbo.BankFeed_MatchTx
            @BankFeedTransactionId = @BankFeedTransactionId,
            @MatchItemsJson        = @MatchItemsJson,
            @MatchedBy             = @EmpId;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        -- BankFeed_MatchTx rolls back on its own failure, which ends this transaction too.
        -- The @@TRANCOUNT guard is what stops a second rollback attempt here. Do not remove it.
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
