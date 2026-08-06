SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- BankFeed_CreateCustomerPaymentDeposit
--   Phase 2b "Receive New Payment": from a pending money-in bank feed row, creates ONE
--   CustomerPayment for the selected payer applying the selected open invoices (and credit
--   memos), wraps it in ONE Deposit, posts both journals, registers the Deposit, and matches
--   the bank row - one transaction, one error path.
--   Plan: plan/bank-feed-create-phase-2-open-invoice.md  (Slice 8, decisions D3/D4/D5/D6/D8/D11)
--
-- Document chain and the two DIFFERENT differences involved:
--   invoices/credits -> CustomerPayment (posts @AR / @UF; NO bank line - Headline Finding)
--                    -> Deposit          (posts @UF / bank; the line the bank row matches)
--   * AR-side shortfall (invoice open balance vs applied): Partial leaves the invoice open;
--     ShortDiscount closes it via the '@IDG' journal line (D6 - ShortDiscount only, the
--     other two discount buckets stay 0).
--   * Bank-side difference (payment net vs bank amount): allocated through Deposit_Insert's
--     own primitives exactly as Phase 2a does - BankFee -> '@ECCDF', Rounding -> '@ERO',
--     Account -> caller-chosen cashback account. bank = net - difference, so the bank
--     amount can never EXCEED the net payment here (50617).
--
-- Credit memos (D11): a credit row applies its FULL (negative) AmountDue or nothing, and
-- carries no discount. Per payer, SUM(net ApplyAmount) must stay > 0 (50614) - a bank
-- deposit line is money in; a credit-only or net-negative selection has no bank event.
--
-- Staging: rows are seeded through TempCustomerPayment_InsertInvoice - the manual screen's
-- own add-invoice procedure - so every auxiliary column (OpenBalanceBefore, term data,
-- SourceType, IsCreditMemo) is computed by the code that owns it. Two targeted UPDATEs
-- follow: PayeeId is re-stamped to the payer (@PayeeId) because InsertInvoice stamps the
-- SHIP-TO payee while CustomerPayment_Insert reads staged rows by the PAYER (F6 - one
-- bill-to payer can span several ship-tos, and CustomerPayment_Inject stamps the payer for
-- the same reason); and the user's Apply/ShortDiscount replace the seeded full-amount
-- default. CustomerPayment_Insert deletes the staged rows itself on success.
--
-- CustomerPayment_Insert opens its own nested transaction (BEGIN TRAN / guarded ROLLBACK
-- on error, like BankFeed_MatchTx) - our outer @@TRANCOUNT guard in CATCH covers it.
-- Extra-disposition parameters are passed as idle (NULL/0): the 50612/50614 invariants make
-- PaymentAmount equal the net applied exactly, so there is never an unapplied extra here.
--
-- Error numbers 50601-50628. Earlier blocks: 50001+ MatchTx, 50101+ P1 create, 50201+ P1
-- lookup, 50301+ reverse, 50401+ P2a create, 50501+ P2 lookups.
-- =============================================================================================

CREATE OR ALTER PROCEDURE [dbo].[BankFeed_CreateCustomerPaymentDeposit]   -- EXEC dbo.BankFeed_CreateCustomerPaymentDeposit @BankFeedTransactionId=1, @PayeeId=1, @PaymentMethod='CHECK', @ReferenceId=NULL, @LinesJson='[{"SalesId":1,"ApplyAmount":10.00,"ShortDiscount":0}]', @DifferenceKind='None', @DifferenceAccountId=NULL, @DifferenceMemo=NULL, @EmpId=1, @NewCustomerPaymentId=NULL, @NewTFId=NULL
    @BankFeedTransactionId BIGINT,
    @PayeeId               INT,
    @PaymentMethod         NVARCHAR(50),
    @ReferenceId           NVARCHAR(200) = NULL,
    @LinesJson             NVARCHAR(MAX),           -- [{"SalesId":..,"ApplyAmount":..,"ShortDiscount":..}]
    @DifferenceKind        VARCHAR(20)   = 'None',  -- bank-side: 'None' | 'BankFee' | 'Rounding' | 'Account'
    @DifferenceAccountId   INT           = NULL,
    @DifferenceMemo        NVARCHAR(500) = NULL,
    @EmpId                 INT,
    @NewCustomerPaymentId  INT           = NULL OUTPUT,
    @NewTFId               INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ---------------------------------------------------------------------------------------
    -- A. Parse the lines. Touches no database state, so it sits outside the transaction.
    ---------------------------------------------------------------------------------------
    IF @LinesJson IS NULL OR ISJSON(@LinesJson) <> 1
        THROW 50606, 'No invoices were selected for this payment.', 1;

    SELECT SalesId,
           ApplyAmount,
           ISNULL(ShortDiscount, 0) AS ShortDiscount
    INTO #Lines
    FROM OPENJSON(@LinesJson)
    WITH (SalesId       INT,
          ApplyAmount   DECIMAL(18,2),
          ShortDiscount DECIMAL(18,2));

    IF NOT EXISTS (SELECT 1 FROM #Lines)
        THROW 50606, 'No invoices were selected for this payment.', 1;

    ---------------------------------------------------------------------------------------
    -- The transaction opens BEFORE validation so the UPDLOCK actually holds (same reasoning
    -- as BankFeed_CreateDeposit). Validation still runs before any write.
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
            THROW 50601, 'Bank feed transaction not found.', 1;

        IF @Status <> 'Pending'
            THROW 50602, 'Only pending bank feed transactions can receive a payment.', 1;

        IF @BankAmount <= 0
            THROW 50603, 'Only money-in bank feed transactions can receive open invoices.', 1;

        IF @BankAccountId IS NULL
            THROW 50604, 'This bank feed row is not mapped to a GL account.', 1;

        IF @IsAccountDebit <> 1
            THROW 50605, 'The GL account mapped to this bank feed is not a debit account.', 1;

        IF EXISTS (SELECT 1 FROM dbo.BankFeedSource
                   WHERE BankFeedTransactionId = @BankFeedTransactionId
                     AND [Status] = 'Active')
            THROW 50607, 'This bank feed row already has a transaction created by Bank Feed. Reverse it first.', 1;

        IF @PayeeId IS NULL OR @PayeeId <= 0
           OR NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE PayeeId = @PayeeId)
            THROW 50608, 'Please select a valid customer.', 1;

        IF EXISTS (SELECT 1 FROM #Lines GROUP BY SalesId HAVING COUNT(*) > 1)
            THROW 50609, 'The same invoice was selected more than once.', 1;

        -- Payer scope: the same bill-to resolution the lookup (and CustomerPayment_Inject)
        -- uses. A payer with a bill-to parent owns every invoice billed to it.
        DECLARE @BillId INT;

        SELECT TOP (1) @BillId = c.BillId
        FROM dbo.Customer AS c
        WHERE c.PayeeId = @PayeeId
          AND c.BillId IS NOT NULL;

        IF EXISTS (SELECT 1
                   FROM #Lines AS l
                   LEFT JOIN dbo.Sales AS s
                       ON s.SalesId = l.SalesId
                      AND ((@BillId IS NOT NULL AND s.BillId = @BillId)
                           OR (@BillId IS NULL AND s.ShipId = @PayeeId))
                   WHERE s.SalesId IS NULL)
            THROW 50610, 'One or more selected invoices do not exist or do not belong to this customer.', 1;

        -- Invoice rows must still be open per D2. Credit memos have no stage rule (D11).
        IF EXISTS (SELECT 1
                   FROM #Lines AS l
                   JOIN dbo.Sales AS s ON s.SalesId = l.SalesId
                   WHERE s.SalesTotal >= 0
                     AND (s.AmountDue <= 0 OR s.StageId < 3))
            THROW 50611, 'One or more selected invoices are no longer open.', 1;

        -- Invoice line rule: Apply >= 0, ShortDiscount >= 0, together > 0 and <= the open
        -- balance. Partial leaves the invoice open; Apply + ShortDiscount = AmountDue
        -- closes it.
        IF EXISTS (SELECT 1
                   FROM #Lines AS l
                   JOIN dbo.Sales AS s ON s.SalesId = l.SalesId
                   WHERE s.SalesTotal >= 0
                     AND (l.ApplyAmount IS NULL OR l.ApplyAmount < 0
                          OR l.ShortDiscount < 0
                          OR l.ApplyAmount + l.ShortDiscount <= 0
                          OR l.ApplyAmount + l.ShortDiscount > s.AmountDue))
            THROW 50612, 'Each selected invoice needs apply plus short discount above zero and within its open balance.', 1;

        -- Credit rule (D11): full (negative) AmountDue, no partial, no discount.
        IF EXISTS (SELECT 1
                   FROM #Lines AS l
                   JOIN dbo.Sales AS s ON s.SalesId = l.SalesId
                   WHERE s.SalesTotal < 0
                     AND (l.ApplyAmount IS NULL
                          OR l.ApplyAmount <> s.AmountDue
                          OR l.ShortDiscount <> 0))
            THROW 50613, 'A credit memo applies its full amount and carries no discount.', 1;

        -- D11: the payer's net must stay positive - a bank deposit line is money in.
        DECLARE @NetApplied         DECIMAL(18,2),
                @ShortDiscountTotal DECIMAL(18,2);

        SELECT @NetApplied         = SUM(ApplyAmount),
               @ShortDiscountTotal = SUM(ShortDiscount)
        FROM #Lines;

        IF @NetApplied <= 0
            THROW 50614, 'The selected credit memos exceed the invoices. A deposit must receive money; use Customer Refund instead.', 1;

        IF @PaymentMethod IS NULL
           OR @PaymentMethod NOT IN ('CHECK', 'ACH', 'E-CHECK', 'CASH', 'CREDIT CARD')
            THROW 50615, 'Unsupported payment method for a bank feed payment.', 1;

        -----------------------------------------------------------------------------------
        -- C1. Bank-side difference, exactly as BankFeed_CreateDeposit computes it:
        --     the bank received net minus whatever was withheld on the way in.
        -----------------------------------------------------------------------------------
        DECLARE @BankDifference DECIMAL(18,2) = @NetApplied - @BankAmount;

        IF @DifferenceKind IS NULL
           OR @DifferenceKind NOT IN ('None', 'BankFee', 'Rounding', 'Account')
            THROW 50616, 'Unsupported difference kind.', 1;

        IF @BankDifference < 0
            THROW 50617, 'The bank amount exceeds the net payment. Apply more invoices; extra money in the bank row cannot be allocated here.', 1;

        IF (@DifferenceKind = 'None' AND @BankDifference <> 0)
           OR (@DifferenceKind <> 'None' AND @BankDifference = 0)
            THROW 50618, 'The net payment minus the allocated difference must equal the bank amount.', 1;

        IF @DifferenceKind = 'Account' AND @DifferenceAccountId IS NULL
            THROW 50619, 'Please choose the account for the difference.', 1;

        IF @DifferenceKind = 'Account'
           AND NOT EXISTS (SELECT 1 FROM dbo.Account WHERE AccountId = @DifferenceAccountId)
            THROW 50620, 'The selected difference account does not exist.', 1;

        IF @DifferenceKind = 'Account'
           AND (@DifferenceAccountId = @BankAccountId
                OR EXISTS (SELECT 1 FROM dbo.Account
                           WHERE AccountId = @DifferenceAccountId AND AccountCode = '@UF'))
            THROW 50621, 'The difference cannot post to the bank account or to Undeposited Funds.', 1;

        IF @DifferenceKind <> 'None'
           AND (@DifferenceMemo IS NULL OR LTRIM(RTRIM(@DifferenceMemo)) = '')
            THROW 50622, 'A memo is required when a difference is allocated.', 1;

        -----------------------------------------------------------------------------------
        -- C2. Draft guards, both staging tables.
        --     TempCustomerPayment: a live selection for THIS payer on the manual payment
        --     screen (CustomerPaymentId = 0, selected, nonzero) would be absorbed by
        --     CustomerPayment_Insert. Inject's untouched candidate rows carry zero amounts
        --     and IsSelected = 0, so they do not block - they are cleared below.
        --     TempTransferFund: same guard Phase 2a ships (50413 there).
        -----------------------------------------------------------------------------------
        IF EXISTS (SELECT 1 FROM dbo.TempCustomerPayment
                   WHERE EmpId = @EmpId
                     AND PayeeId = @PayeeId
                     AND CustomerPaymentId = 0
                     AND ISNULL(IsSelected, IsApplied) = 1
                     AND (ISNULL(PaymentApplied, 0) <> 0
                          OR ISNULL(DiscountApplied, 0) <> 0
                          OR ISNULL(PaymentDiscount, 0) <> 0
                          OR ISNULL(ShortDiscount, 0) <> 0
                          OR ISNULL(OtherDiscount, 0) <> 0))
            THROW 50623, 'You have an unsaved customer payment draft for this customer. Finish or discard it first.', 1;

        IF EXISTS (SELECT 1 FROM dbo.TempTransferFund
                   WHERE EmpId = @EmpId AND IsApplied = 1)
            THROW 50624, 'You have an unsaved deposit in progress on the Deposit screen. Finish or close it first.', 1;

        -----------------------------------------------------------------------------------
        -- D. Clear staging residue, then seed through the manual screen's own procedure.
        --    TempCustomerPayment_InsertInvoice computes every auxiliary column from Sales;
        --    the UPDATE then re-stamps the payer (see header) and applies the user's
        --    amounts over the seeded full-amount default.
        -----------------------------------------------------------------------------------
        DELETE FROM dbo.TempCustomerPayment
        WHERE EmpId = @EmpId AND PayeeId = @PayeeId AND CustomerPaymentId = 0;

        DELETE FROM dbo.TempTransferFund WHERE EmpId = @EmpId;

        DECLARE @LineSalesId     INT,
                @LineApply       DECIMAL(18,2),
                @LineShort       DECIMAL(18,2),
                @LineSalesNumber INT,
                @LineTempId      INT;

        DECLARE line_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT l.SalesId, l.ApplyAmount, l.ShortDiscount, s.SalesNumber
            FROM #Lines AS l
            JOIN dbo.Sales AS s ON s.SalesId = l.SalesId;

        OPEN line_cursor;
        FETCH NEXT FROM line_cursor INTO @LineSalesId, @LineApply, @LineShort, @LineSalesNumber;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @LineTempId = NULL;   -- reset per iteration; a stale id would target the wrong row

            EXEC dbo.TempCustomerPayment_InsertInvoice
                @EmpId             = @EmpId,
                @CustomerPaymentId = 0,
                @SalesNumber       = @LineSalesNumber,
                @TempId            = @LineTempId OUTPUT;

            IF @LineTempId IS NULL
                THROW 50625, 'Could not stage a selected invoice.', 1;

            -- DiscountApplied is a computed column (PaymentDiscount + ShortDiscount +
            -- OtherDiscount) and follows ShortDiscount by itself - never set it directly.
            UPDATE dbo.TempCustomerPayment
            SET PayeeId        = @PayeeId,
                PaymentApplied = @LineApply,
                ShortDiscount  = @LineShort,
                IsApplied      = 1,
                IsSelected     = 1
            WHERE TempCPId = @LineTempId;

            FETCH NEXT FROM line_cursor INTO @LineSalesId, @LineApply, @LineShort, @LineSalesNumber;
        END;

        CLOSE line_cursor;
        DEALLOCATE line_cursor;

        -----------------------------------------------------------------------------------
        -- E. Create the payment. PaymentAmount = net applied = what reaches @UF; the
        --    invariants above make an unapplied extra impossible, so the disposition
        --    parameters stay idle. @FromAccountId is NULL on purpose - rev 3 discards it
        --    for 'Actual Payment' anyway (Headline Finding). The procedure deletes the
        --    staged rows itself and runs its own journal balance check (50014).
        -----------------------------------------------------------------------------------
        DECLARE @Notes NVARCHAR(255) = LEFT(N'Bank feed: ' + ISNULL(@Description, N''), 255);

        EXEC dbo.CustomerPayment_Insert
            @CustomerPaymentId              = 0,
            @PaymentType                    = N'Actual Payment',
            @PayeeId                        = @PayeeId,
            @PaymentDate                    = @PostedDate,
            @PaymentMethod                  = @PaymentMethod,
            @FromAccountId                  = NULL,
            @ReferenceId                    = @ReferenceId,
            @PaymentAmount                  = @NetApplied,
            @Notes                          = @Notes,
            @CCFee                          = 0,
            @PreviousExtraDisposition       = NULL,
            @NewExtraDisposition            = NULL,
            @ExtraDispositionChanged        = 0,
            @SelectedExtraDispositionAmount = 0,
            @EmpId                          = @EmpId,
            @NewPaymentId                   = @NewCustomerPaymentId OUTPUT;

        IF @NewCustomerPaymentId IS NULL OR @NewCustomerPaymentId <= 0
            THROW 50626, 'The customer payment could not be created.', 1;

        -----------------------------------------------------------------------------------
        -- F. Wrap it in a deposit. Same mechanics as BankFeed_CreateDeposit step C-E:
        --    seed the one payment, map the bank-side difference onto Deposit_Insert's
        --    primitives, and let it post @UF -> bank.
        -----------------------------------------------------------------------------------
        INSERT INTO dbo.TempTransferFund
            (EmpId, TFId, CustomerPaymentId, DepositAmount, Notes, IsApplied)
        VALUES
            (@EmpId, 0, @NewCustomerPaymentId, @NetApplied, NULL, 1);

        DECLARE @CashbackAccountId INT           = NULL,
                @CashbackAmount    DECIMAL(18,2) = 0,
                @CCFeeAmount       DECIMAL(18,2) = 0,
                @RoundingOff       DECIMAL(18,2) = 0;

        IF @DifferenceKind = 'BankFee'  SET @CCFeeAmount = @BankDifference;
        IF @DifferenceKind = 'Rounding' SET @RoundingOff = @BankDifference;
        IF @DifferenceKind = 'Account'
        BEGIN
            SET @CashbackAmount    = @BankDifference;
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
            THROW 50627, 'The deposit could not be created.', 1;

        -----------------------------------------------------------------------------------
        -- G. Locate the DEPOSIT journal - the payment journal has no bank line and is never
        --    the match target (D4). Same single-row asserts as Phase 2a.
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
            THROW 50628, 'Could not identify the journal transaction for the new deposit.', 1;

        SELECT @RowCheck = COUNT(*), @TxDetailId = MIN(TxDetailId)
        FROM dbo.TransactionJournalDetail
        WHERE TxId = @TxId
          AND AccountId = @BankAccountId;

        IF @RowCheck <> 1
            THROW 50628, 'Could not identify the bank line of the new journal transaction.', 1;

        -----------------------------------------------------------------------------------
        -- H. Register what Bank Feed generated. SourceDocType is the DEPOSIT (D8); the
        --    generated payment is discoverable through TransferFundDetail, and the reverse
        --    procedure reads that link BEFORE deleting the TransferFund (Slice 9).
        --    DifferenceAmount/Resolution describe the BANK-side difference, as in 2a; the
        --    AR-side short discount lives in the payment document itself.
        -----------------------------------------------------------------------------------
        INSERT INTO dbo.BankFeedSource
            (BankFeedTransactionId, SourceDocType, SourceDocId, TxId,
             [Mode], [Status], OriginalBankAmount, AppliedAmount, DifferenceAmount,
             DifferenceResolution, DifferenceAccountId, DifferenceMemo, CreatedAt, CreatedBy)
        VALUES
            (@BankFeedTransactionId, 'Deposit', @NewTFId, @TxId,
             'ReceiveOpenInvoice', 'Active', @BankAmount, @NetApplied, @BankDifference,
             @DifferenceKind, @DifferenceAccountId, @DifferenceMemo, SYSUTCDATETIME(), @EmpId);

        -----------------------------------------------------------------------------------
        -- I. Match through the existing path, so create and manual match cannot drift.
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
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
