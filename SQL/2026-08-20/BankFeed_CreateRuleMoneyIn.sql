SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- BankFeed_CreateRuleMoneyIn
--   Creates one account-based Other Incoming Payment from a pending money-in bank feed row,
--   registers the generated source, and matches the bank line.
--   Plan: plan-03b-bank-feed-rule-money-in-apply.md (Slice 2)
--
-- This is a wrapper around the existing IncomingPayment_Insert source-doc path. It does not
-- introduce a new accounting document. The wrapper owns Bank Feed safety: row lock, duplicate
-- generated-source guard, fallback payee, journal lookup, BankFeedSource registration, and
-- BankFeed_MatchTx.
--
-- Error numbers 50801-50822. Neighbouring bands: 50001 MatchTx, 50101 vendor create,
-- 50301 reverse, 50401 deposit create, 50601 invoice deposit create, 50701 liability payment.
-- =============================================================================================

CREATE OR ALTER PROCEDURE [dbo].[BankFeed_CreateRuleMoneyIn]  -- EXEC dbo.BankFeed_CreateRuleMoneyIn @BankFeedTransactionId=1, @PayeeId=NULL, @AccountId=127, @ReferenceId=NULL, @Notes=N'Rule income', @AppendBankDesc=1, @EmpId=1, @NewCustomerPaymentId=NULL
    @BankFeedTransactionId BIGINT,
    @PayeeId               INT           = NULL,
    @AccountId             INT,
    @ReferenceId           NVARCHAR(100) = NULL,
    @Notes                 NVARCHAR(255) = NULL,
    @AppendBankDesc        BIT           = 1,
    @EmpId                 INT,
    @NewCustomerPaymentId  INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;
    BEGIN TRY

        -----------------------------------------------------------------------------------
        -- A. Load and lock the bank feed row. The lock makes the active-source guard below
        --    meaningful when two users try to apply the same suggestion.
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

        IF @Status IS NULL
            THROW 50801, 'Bank feed transaction not found.', 1;

        IF @Status <> 'Pending'
            THROW 50802, 'Only pending bank feed transactions can create rule money-in.', 1;

        IF @BankAmount <= 0
            THROW 50803, 'Only money-in bank feed transactions can create rule money-in.', 1;

        IF @BankAccountId IS NULL
            THROW 50804, 'This bank feed row is not mapped to a GL account.', 1;

        IF @IsAccountDebit <> 1
            THROW 50805, 'Rule money-in only supports debit-side bank or cash accounts.', 1;

        IF EXISTS (SELECT 1 FROM dbo.BankFeedSource
                   WHERE BankFeedTransactionId = @BankFeedTransactionId
                     AND [Status] = 'Active')
            THROW 50806, 'This bank feed row already has a transaction created by Bank Feed. Reverse it first.', 1;

        -----------------------------------------------------------------------------------
        -- B. Validate the target account. IncomingPayment_Insert will credit this account;
        --    block clearing/control accounts and the bank account itself.
        -----------------------------------------------------------------------------------
        IF @AccountId IS NULL
            THROW 50807, 'Rule money-in account is required.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Account WHERE AccountId = @AccountId AND Inactive = 0)
            THROW 50808, 'Rule money-in account is missing or inactive.', 1;

        IF @AccountId = @BankAccountId
            THROW 50809, 'Rule money-in account cannot be the bank feed account.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Account
                   WHERE AccountId = @AccountId
                     AND AccountCode IN ('@UF', '@AR', '@AP'))
            THROW 50810, 'Rule money-in account cannot be Undeposited Funds, Accounts Receivable, or Accounts Payable.', 1;

        -----------------------------------------------------------------------------------
        -- C. Resolve payee. User payee is optional; when blank, use the hidden fallback
        --    seeded by BankFeedRuleMoneyIn_FallbackPayee.sql.
        -----------------------------------------------------------------------------------
        DECLARE @PostingPayeeId INT = @PayeeId;

        IF @PostingPayeeId IS NULL
        BEGIN
            SELECT @PostingPayeeId = PayeeId
            FROM dbo.Payee
            WHERE PayeeName = N'Bank Feed Income'
              AND IsClosed = 0;

            IF @PostingPayeeId IS NULL
                THROW 50811, 'Bank Feed Income fallback payee is missing. Deploy the fallback payee seed first.', 1;
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM dbo.Payee
                            WHERE PayeeId = @PostingPayeeId
                              AND IsClosed = 0)
            THROW 50812, 'Rule money-in payee is missing or inactive.', 1;

        -----------------------------------------------------------------------------------
        -- D. Create the source document through the existing Incoming Payments engine.
        -----------------------------------------------------------------------------------
        DECLARE @DocNotes NVARCHAR(255) =
            CASE WHEN @AppendBankDesc = 1
                 THEN LEFT(ISNULL(NULLIF(LTRIM(RTRIM(@Notes)), N'') + N' - ', N'')
                           + N'Bank feed: ' + ISNULL(@Description, N''), 255)
                 ELSE NULLIF(LTRIM(RTRIM(@Notes)), N'')
            END;

        EXEC dbo.IncomingPayment_Insert
            @CustomerPaymentId     = 0,
            @PayeeId               = @PostingPayeeId,
            @PaymentDate           = @PostedDate,
            @PaymentMethod         = N'ACH',
            @FromAccountId         = @BankAccountId,
            @ReferenceId           = @ReferenceId,
            @PaymentAmount         = @BankAmount,
            @Notes                 = @DocNotes,
            @AccountId1            = @AccountId,
            @AccountId2            = NULL,
            @AccountId3            = NULL,
            @AccountId4            = NULL,
            @Amount1               = @BankAmount,
            @Amount2               = 0,
            @Amount3               = 0,
            @Amount4               = 0,
            @NewCustomerPaymentId  = @NewCustomerPaymentId OUTPUT;

        IF @NewCustomerPaymentId IS NULL OR @NewCustomerPaymentId <= 0
            THROW 50813, 'The rule money-in incoming payment could not be created.', 1;

        -----------------------------------------------------------------------------------
        -- E. Locate the generated journal and its bank line. Assert single rows; this is
        --    accounting, so a duplicate should stop instead of guessing.
        -----------------------------------------------------------------------------------
        DECLARE @PaymentNumber INT,
                @PaymentType   NVARCHAR(100),
                @TxId          BIGINT,
                @TxDetailId    BIGINT,
                @RowCheck      INT;

        SELECT @PaymentNumber = PaymentNumber,
               @PaymentType   = PaymentType
        FROM dbo.CustomerPayment
        WHERE CustomerPaymentId = @NewCustomerPaymentId;

        IF @PaymentType <> N'Other Incoming Payment'
            THROW 50814, 'The generated payment is not an Other Incoming Payment.', 1;

        SELECT @RowCheck = COUNT(*), @TxId = MIN(TxId)
        FROM dbo.TransactionJournal
        WHERE SourceDocType   = N'Other Incoming Payment'
          AND SourceDocNumber = @PaymentNumber;

        IF @RowCheck <> 1
            THROW 50815, 'Could not identify the journal transaction for the new incoming payment.', 1;

        SELECT @RowCheck = COUNT(*), @TxDetailId = MIN(TxDetailId)
        FROM dbo.TransactionJournalDetail
        WHERE TxId = @TxId
          AND AccountId = @BankAccountId;

        IF @RowCheck <> 1
            THROW 50816, 'Could not identify the bank line of the new incoming payment journal.', 1;

        -----------------------------------------------------------------------------------
        -- F. Register and match through the existing Bank Feed matching engine.
        -----------------------------------------------------------------------------------
        INSERT INTO dbo.BankFeedSource
            (BankFeedTransactionId, SourceDocType, SourceDocId, TxId,
             [Mode], [Status], OriginalBankAmount, AppliedAmount, DifferenceAmount,
             DifferenceResolution, DifferenceAccountId, DifferenceMemo, CreatedAt, CreatedBy)
        VALUES
            (@BankFeedTransactionId, 'CustomerPayment', @NewCustomerPaymentId, @TxId,
             'RuleMoneyIn', 'Active', @BankAmount, @BankAmount, 0,
             'None', NULL, NULL, SYSUTCDATETIME(), @EmpId);

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
