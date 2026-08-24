SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- BankFeed_CreateTransfer
--   Creates a TransferFund transfer from a pending bank feed row, posts the journal through
--   TransferFund_Insert, registers the generated document, and matches the bank row.
--   Plan: plan-03c-bank-feed-rule-transfer-apply.md (Slice 3)
--
-- TransferFund_Insert is the existing manual-transfer posting engine. This wrapper only owns
-- Bank Feed-specific validation, direction, tracing, and matching.
--
-- Direction is derived from the signed bank row:
--   bank amount < 0: mapped bank account -> target account
--   bank amount > 0: target account -> mapped bank account
--
-- V1 deliberately supports Bank/Cash only. Credit-card activity is represented elsewhere in
-- KLS as VendorPayment / liability-payment flows, not TransferFund transfers.
--
-- Error numbers 50801-50814.
-- =============================================================================================

CREATE OR ALTER PROCEDURE [dbo].[BankFeed_CreateTransfer]  -- EXEC dbo.BankFeed_CreateTransfer @BankFeedTransactionId=1, @TargetAccountId=281, @ReferenceId=NULL, @Notes=N'Rule transfer', @AppendBankDesc=1, @EmpId=100001, @NewTFId=NULL
    @BankFeedTransactionId BIGINT,
    @TargetAccountId       INT,
    @ReferenceId           NVARCHAR(100) = NULL,
    @Notes                 NVARCHAR(255) = NULL,
    @AppendBankDesc        BIT           = 1,
    @EmpId                 INT,
    @NewTFId               INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRAN;
    BEGIN TRY

        -----------------------------------------------------------------------------------
        -- A. Load and lock the bank row plus its mapped GL account.
        -----------------------------------------------------------------------------------
        DECLARE @Status            VARCHAR(20),
                @PostedDate        DATE,
                @BankAmount        DECIMAL(18,2),
                @Description       NVARCHAR(500),
                @BankAccountId     INT,
                @BankAccountType   NVARCHAR(50),
                @BankAccountClosed BIT,
                @BankFeedIsActive  BIT;

        SELECT @Status            = bft.[Status],
               @PostedDate        = bft.PostedDate,
               @BankAmount        = bft.Amount,
               @Description       = bft.[Description],
               @BankAccountId     = bfa.AccountId,
               @BankFeedIsActive  = bfa.IsActive,
               @BankAccountType   = a.TypeName,
               @BankAccountClosed = a.Inactive
        FROM dbo.BankFeedTransaction AS bft WITH (UPDLOCK, HOLDLOCK)
        LEFT JOIN dbo.BankFeedAccount AS bfa
            ON bfa.BankFeedAccountId = bft.BankFeedAccountId
        LEFT JOIN dbo.Account AS a
            ON a.AccountId = bfa.AccountId
        WHERE bft.BankFeedTransactionId = @BankFeedTransactionId;

        -----------------------------------------------------------------------------------
        -- B. Validate. Nothing has been written yet.
        -----------------------------------------------------------------------------------
        IF @Status IS NULL
            THROW 50801, 'Bank feed transaction not found.', 1;

        IF @Status <> 'Pending'
            THROW 50802, 'Only pending bank feed transactions can create a transfer.', 1;

        IF @BankAmount = 0
            THROW 50803, 'Zero amount bank feed transactions cannot create a transfer.', 1;

        IF @BankAccountId IS NULL
            THROW 50804, 'This bank feed row is not mapped to a GL account.', 1;

        IF @BankFeedIsActive <> 1 OR ISNULL(@BankAccountClosed, 1) <> 0
            THROW 50805, 'The bank feed mapped account is inactive.', 1;

        IF ISNULL(@BankAccountType, '') <> 'Bank'
            THROW 50806, 'Rule transfer requires the bank feed account to be a Bank account.', 1;

        DECLARE @TargetType NVARCHAR(50),
                @TargetClosed BIT;

        SELECT @TargetType = TypeName,
               @TargetClosed = Inactive
        FROM dbo.Account
        WHERE AccountId = @TargetAccountId;

        IF @TargetType IS NULL
            THROW 50807, 'Transfer target account was not found.', 1;

        IF @TargetClosed <> 0
            THROW 50808, 'Transfer target account is inactive.', 1;

        IF @TargetType NOT IN ('Bank', 'Cash')
            THROW 50809, 'Rule transfer target account must be Bank or Cash.', 1;

        IF @TargetAccountId = @BankAccountId
            THROW 50810, 'Transfer target account cannot be the bank feed account.', 1;

        IF EXISTS (SELECT 1 FROM dbo.BankFeedSource
                   WHERE BankFeedTransactionId = @BankFeedTransactionId
                     AND [Status] = 'Active')
            THROW 50811, 'This bank feed row already has a transaction created by Bank Feed. Reverse it first.', 1;

        -----------------------------------------------------------------------------------
        -- C. Derive direction, then create the TransferFund document through the existing
        --    posting engine.
        -----------------------------------------------------------------------------------
        DECLARE @FromAccountId  INT,
                @ToAccountId    INT,
                @TransferAmount DECIMAL(18,2) = ABS(@BankAmount);

        IF @BankAmount < 0
        BEGIN
            SET @FromAccountId = @BankAccountId;
            SET @ToAccountId = @TargetAccountId;
        END
        ELSE
        BEGIN
            SET @FromAccountId = @TargetAccountId;
            SET @ToAccountId = @BankAccountId;
        END;

        DECLARE @DocNotes NVARCHAR(255) =
            CASE WHEN @AppendBankDesc = 1
                 THEN LEFT(ISNULL(NULLIF(LTRIM(RTRIM(@Notes)), N'') + N' - ', N'')
                           + N'Bank feed: ' + ISNULL(@Description, N''), 255)
                 ELSE NULLIF(LTRIM(RTRIM(@Notes)), N'')
            END;

        EXEC dbo.TransferFund_Insert
            @TFId           = 0,
            @TFDate         = @PostedDate,
            @FromAccountId  = @FromAccountId,
            @ToAccountId    = @ToAccountId,
            @ReferenceId    = @ReferenceId,
            @TransferAmount = @TransferAmount,
            @Notes          = @DocNotes,
            @NewTFId        = @NewTFId OUTPUT;

        IF @NewTFId IS NULL OR @NewTFId <= 0
            THROW 50812, 'The transfer could not be created.', 1;

        -----------------------------------------------------------------------------------
        -- D. Locate the journal and the mapped-bank line whose signed Amount equals the
        --    bank feed row. This is the line BankFeed_MatchTx must receive.
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
        WHERE SourceDocType   = 'Transfer'
          AND SourceDocNumber = @TFNumber;

        IF @RowCheck <> 1
            THROW 50813, 'Could not identify the journal transaction for the new transfer.', 1;

        SELECT @RowCheck = COUNT(*), @TxDetailId = MIN(TxDetailId)
        FROM dbo.TransactionJournalDetail
        WHERE TxId = @TxId
          AND AccountId = @BankAccountId
          AND Amount = @BankAmount;

        IF @RowCheck <> 1
            THROW 50814, 'Could not identify the bank line of the new transfer journal.', 1;

        -----------------------------------------------------------------------------------
        -- E. Register and match through the existing Bank Feed matching path.
        -----------------------------------------------------------------------------------
        INSERT INTO dbo.BankFeedSource
            (BankFeedTransactionId, SourceDocType, SourceDocId, TxId,
             [Mode], [Status], OriginalBankAmount, AppliedAmount, DifferenceAmount,
             DifferenceResolution, DifferenceMemo, CreatedAt, CreatedBy)
        VALUES
            (@BankFeedTransactionId, 'Transfer', @NewTFId, @TxId,
             'RuleTransfer', 'Active', @BankAmount, @TransferAmount, 0,
             'None', NULL, SYSUTCDATETIME(), @EmpId);

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
