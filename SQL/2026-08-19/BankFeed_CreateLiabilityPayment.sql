SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- BankFeed_CreateLiabilityPayment
--   Creates a Tax Manager payment (sales / payroll / income / other tax) or a Loan Manager
--   repayment from a pending money-out bank feed row, posts the journal through the existing
--   liability engine, registers what was generated, and matches the bank row.
--   Plan: plan/bank-feed-liability-payment-v1.md  (Slice 1, decisions D1-D14)
--
-- NEW procedure 2026-08-19 - no live baseline exists (verified: OBJECT_ID('dbo.BankFeed_
-- CreateLiabilityPayment') IS NULL in KLS-2026 during precheck the same day).
--
-- This is a WRAPPER, not a re-implementation: all posting goes through
-- Liability_InsertLoanPayment - the exact SP Tax Manager and Loan Manager save with. That SP
-- derives PaymentType from Payee.PayeeType (L-TAXS/L-TAXP/L-TAXI/L-TAXO -> the tax branch,
-- 2-line journal on Liability.AccountId1; anything else -> 'Loan Repayment', up to 4 lines
-- with the Principal/Interest/LateFee split), signs everything through Fn_Adjust_CrDeAmount,
-- and has no transaction of its own, so it runs inside this procedure's transaction the same
-- way VendorPayment_Insert runs inside BankFeed_CreateVendorPayment's.
--
-- The kind is derived HERE from PayeeType too (D13) - the client never sends it:
--   tax payee  -> the split params must all be zero (the document is one amount);
--   loan payee -> the split must sum to ABS(bank amount) (the split allocates the debit,
--                 it never changes it - D3);
--   L-CC (own SaveCCPayment path, D14) and L-LOC (in no manager list, D12) are refused.
--
-- Not accepted as parameters, by design (the BankFeed_CreateVendorPayment precedent):
--   @PaymentDate     - always the bank row's PostedDate (D4)
--   @PaymentAmount   - always ABS(bank amount), no partial, no difference block (D3)
--   @FromAccountId   - always the bank row's mapped GL account
--
-- Error numbers 50701-50715 (D11). Neighbouring bands: 50001 MatchTx, 50101 P1 create,
-- 50201 P1 lookup, 50301 reverse, 50401 P2 create, 50501 P2a lookup, 50601 2b create.
--
-- Reverse needs NO changes (verified against the full live body 2026-08-19, D8):
-- BankFeed_ReverseGenerated admits SourceDocType='VendorPayment', its validations are
-- existence + not-voided only, and TRG_Delete_VendorPmtTx deletes the journal by
-- (PaymentType, PaymentNumber) - exactly what Liability_InsertLoanPayment wrote.
-- =============================================================================================

CREATE OR ALTER PROCEDURE [dbo].[BankFeed_CreateLiabilityPayment]
    -- EXEC dbo.BankFeed_CreateLiabilityPayment @BankFeedTransactionId=1, @PayeeId=100050,
    --      @PaymentMethod='ACH', @ReferenceId=NULL, @Notes=NULL,
    --      @Principal=0, @Interest=0, @LateFee=0, @AppendBankDesc=1,
    --      @EmpId=100001, @NewVendorPaymentId=NULL
    @BankFeedTransactionId BIGINT,
    @PayeeId               INT,
    @PaymentMethod         NVARCHAR(50),
    @ReferenceId           NVARCHAR(100) = NULL,
    @Notes                 NVARCHAR(255) = NULL,
    @Principal             DECIMAL(18,2) = 0,   -- loan payees only (D13)
    @Interest              DECIMAL(18,2) = 0,   -- loan payees only
    @LateFee               DECIMAL(18,2) = 0,   -- loan payees only
    @AppendBankDesc        BIT           = 1,   -- 1 = append the bank description to notes (D10)
    @EmpId                 INT,
    @NewVendorPaymentId    INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- NULLs from a caller behave as "not entered", same as the defaults.
    SET @Principal = ISNULL(@Principal, 0);
    SET @Interest  = ISNULL(@Interest, 0);
    SET @LateFee   = ISNULL(@LateFee, 0);

    ---------------------------------------------------------------------------------------
    -- The transaction opens BEFORE validation on purpose (the create-vendor-payment rule):
    -- the UPDLOCK on BankFeedTransaction only holds for the life of a transaction. Without
    -- it two users clicking Create on the same bank row would both pass the "no Active
    -- BankFeedSource" check and both create a payment. Validation still runs before any
    -- write, so a THROW here rolls back nothing.
    ---------------------------------------------------------------------------------------
    BEGIN TRAN;
    BEGIN TRY

        -----------------------------------------------------------------------------------
        -- A. Load the bank feed row and the GL account it maps to
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
        -- B. Validate. Everything THROWs; nothing has been written yet.
        -----------------------------------------------------------------------------------
        IF @Status IS NULL
            THROW 50701, 'Bank feed transaction not found.', 1;

        IF @Status <> 'Pending'
            THROW 50702, 'Only pending bank feed transactions can create a liability payment.', 1;

        IF @BankAmount >= 0
            THROW 50703, 'Only money-out bank feed transactions can create a liability payment.', 1;

        IF @BankAccountId IS NULL
            THROW 50704, 'This bank feed row is not mapped to a GL account.', 1;

        -- The bank line posts as -PaymentAmount only for a debit (asset) account. On a credit
        -- account the sign flips and BankFeed_MatchTx would reject the amount with a much less
        -- helpful message, so catch the misconfiguration here.
        IF @IsAccountDebit <> 1
            THROW 50705, 'The GL account mapped to this bank feed is not a debit account.', 1;

        IF EXISTS (SELECT 1 FROM dbo.BankFeedSource
                   WHERE BankFeedTransactionId = @BankFeedTransactionId
                     AND [Status] = 'Active')
            THROW 50706, 'This bank feed row already has a transaction created by Bank Feed. Reverse it first.', 1;

        -- 'CHECK' is excluded: Liability_InsertLoanPayment would call Get_CheckNumber, which
        -- overwrites @ReferenceId and consumes a number from CheckTracker. A bank feed row
        -- already carries its own check number, so both behaviours are wrong here (D5).
        IF @PaymentMethod IS NULL
           OR @PaymentMethod NOT IN ('ACH', 'E-CHECK', 'CASH', 'HANDWRITE CHECK', 'CREDIT CARD')
            THROW 50707, 'Unsupported payment method for a bank feed liability payment.', 1;

        -----------------------------------------------------------------------------------
        -- C. Load the payee and derive the kind from PayeeType (D12/D13) - the same seam
        --    Liability_InsertLoanPayment branches on, checked here so a bad payee fails
        --    with a named error instead of a half-posted document.
        -----------------------------------------------------------------------------------
        DECLARE @PayeeType          NVARCHAR(100),
                @LiabilityAccountId INT,
                @IsTax              BIT;

        SELECT @PayeeType          = p.PayeeType,
               @LiabilityAccountId = l.AccountId1
        FROM dbo.Liability AS l
        INNER JOIN dbo.Payee AS p
            ON p.PayeeId = l.PayeeId
        WHERE l.PayeeId = @PayeeId;

        IF @PayeeType IS NULL
            THROW 50708, 'The selected payee is not a liability payee.', 1;

        IF @PayeeType IN ('L-TAXS', 'L-TAXP', 'L-TAXI', 'L-TAXO')
            SET @IsTax = 1;
        ELSE IF @PayeeType LIKE 'L-LOAN%'
            SET @IsTax = 0;
        ELSE
            -- L-CC has its own payment path (SaveCCPayment, D14); L-LOC is in no manager
            -- list (D12). Anything else is not a liability this feature knows how to pay.
            THROW 50709, 'Only tax and loan liability payees can be paid from Bank Feed.', 1;

        -- The tax branch posts the whole amount to AccountId1; the loan branch posts
        -- Principal to it. A NULL would produce a NULL-account journal line, not an error.
        IF @LiabilityAccountId IS NULL
            THROW 50710, 'The selected liability payee has no liability account configured.', 1;

        -----------------------------------------------------------------------------------
        -- D. Amount and split rules (D3/D13). The payment always equals the bank debit.
        -----------------------------------------------------------------------------------
        DECLARE @PaymentAmount DECIMAL(18,2) = ABS(@BankAmount);

        IF @IsTax = 1 AND (@Principal <> 0 OR @Interest <> 0 OR @LateFee <> 0)
            THROW 50711, 'A tax payment has no principal/interest split.', 1;

        IF @IsTax = 0 AND (@Principal + @Interest + @LateFee) <> @PaymentAmount
            THROW 50712, 'Principal, interest and late fee must add up to the bank amount.', 1;

        IF @Principal < 0 OR @Interest < 0 OR @LateFee < 0
            THROW 50713, 'Split amounts cannot be negative.', 1;

        -----------------------------------------------------------------------------------
        -- E. Create the payment through the existing liability engine. Notes follow the
        --    append-desc convention (D10): the bank description is appended when opted in,
        --    after any user note.
        -----------------------------------------------------------------------------------
        DECLARE @DocNotes NVARCHAR(255) =
            CASE WHEN @AppendBankDesc = 1
                 THEN LEFT(ISNULL(NULLIF(LTRIM(RTRIM(@Notes)), N'') + N' - ', N'')
                           + N'Bank feed: ' + ISNULL(@Description, N''), 255)
                 ELSE NULLIF(LTRIM(RTRIM(@Notes)), N'')
            END;

        DECLARE @NewPaymentId INT;

        EXEC dbo.Liability_InsertLoanPayment
            @VendorPaymentId = 0,
            @PayeeId         = @PayeeId,
            @PaymentDate     = @PostedDate,
            @PaymentMethod   = @PaymentMethod,
            @ReferenceId     = @ReferenceId,
            @FromAccountId   = @BankAccountId,
            @PaymentAmount   = @PaymentAmount,
            @Notes           = @DocNotes,
            @Principal       = @Principal,
            @Interest        = @Interest,
            @LateFee         = @LateFee,
            @NewPaymentId    = @NewPaymentId OUTPUT;

        IF @NewPaymentId IS NULL
            THROW 50714, 'Could not identify the journal transaction for the new payment.', 1;

        -----------------------------------------------------------------------------------
        -- F. Locate the journal it posted and its bank line - the create-vendor-payment
        --    COUNT/MIN pattern, so a duplicate or missing journal fails loudly.
        -----------------------------------------------------------------------------------
        DECLARE @PaymentNumber INT,
                @PaymentType   NVARCHAR(100),
                @TxId          BIGINT,
                @TxDetailId    BIGINT,
                @RowCheck      INT;

        SELECT @PaymentNumber = PaymentNumber,
               @PaymentType   = PaymentType
        FROM dbo.VendorPayment
        WHERE VendorPaymentId = @NewPaymentId;

        SELECT @RowCheck = COUNT(*), @TxId = MIN(TxId)
        FROM dbo.TransactionJournal
        WHERE SourceDocType   = @PaymentType
          AND SourceDocNumber = @PaymentNumber;

        IF @RowCheck <> 1
            THROW 50714, 'Could not identify the journal transaction for the new payment.', 1;

        SELECT @RowCheck = COUNT(*), @TxDetailId = MIN(TxDetailId)
        FROM dbo.TransactionJournalDetail
        WHERE TxId = @TxId
          AND AccountId = @BankAccountId;

        -- Also cleanly refuses the degenerate config where the liability account IS the
        -- bank GL account (two lines would match).
        IF @RowCheck <> 1
            THROW 50715, 'Could not identify the bank line of the new journal transaction.', 1;

        -----------------------------------------------------------------------------------
        -- G. Register what Bank Feed generated, so it can be traced and reversed (D7).
        --    OriginalBankAmount keeps the SIGNED bank amount; the payment has no difference
        --    of its own because it is created to equal the bank row (D3).
        -----------------------------------------------------------------------------------
        INSERT INTO dbo.BankFeedSource
            (BankFeedTransactionId, SourceDocType, SourceDocId, TxId,
             [Mode], [Status], OriginalBankAmount, AppliedAmount, DifferenceAmount,
             DifferenceResolution, DifferenceMemo, CreatedAt, CreatedBy)
        VALUES
            (@BankFeedTransactionId, 'VendorPayment', @NewPaymentId, @TxId,
             'LiabilityPayment', 'Active', @BankAmount, @PaymentAmount, 0,
             'None', NULL, SYSUTCDATETIME(), @EmpId);

        SET @NewVendorPaymentId = @NewPaymentId;

        -----------------------------------------------------------------------------------
        -- H. Match through the existing path, so create and manual match cannot drift.
        --    It re-validates account / amount / not-already-matched, sets the journal
        --    BankDate, and moves the header to Matched.
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
GO
