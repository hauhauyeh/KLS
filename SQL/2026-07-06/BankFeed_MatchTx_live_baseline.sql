

CREATE PROCEDURE [dbo].[BankFeed_MatchTx]
    @BankFeedTransactionId BIGINT,
    @MatchItemsJson NVARCHAR(MAX),
    @MatchedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- 1. Parse JSON into temp table
    SELECT TxId, TxDetailId
    INTO #MatchItems
    FROM OPENJSON(@MatchItemsJson)
    WITH (TxId BIGINT, TxDetailId BIGINT);

    -- 2. Validate bank feed tx exists and is not Excluded
    DECLARE @Status VARCHAR(20),
            @PostedDate DATE,
            @BankFeedAmount DECIMAL(18,2);

    SELECT @Status = Status,
           @PostedDate = PostedDate,
           @BankFeedAmount = Amount
    FROM BankFeedTransaction
    WHERE BankFeedTransactionId = @BankFeedTransactionId;

    IF @Status IS NULL
        THROW 50001, 'Bank feed transaction not found.', 1;
    IF @Status = 'Excluded'
        THROW 50002, 'Excluded transactions cannot be matched.', 1;

    -- 3. Validate all TxDetailIds exist and belong to their TxIds
    IF EXISTS (
        SELECT 1 FROM #MatchItems mi
        WHERE NOT EXISTS (
            SELECT 1 FROM TransactionJournalDetail td
            WHERE td.TxDetailId = mi.TxDetailId AND td.TxId = mi.TxId
        )
    )
        THROW 50003, 'One or more transaction details not found or do not belong to the specified transaction.', 1;

    -- 4. Validate TxDetailIds belong to the bank feed account
    DECLARE @AccountId INT;

    SELECT @AccountId = bfa.AccountId
    FROM BankFeedTransaction bft
    JOIN BankFeedAccount bfa ON bfa.BankFeedAccountId = bft.BankFeedAccountId
    WHERE bft.BankFeedTransactionId = @BankFeedTransactionId;

    IF EXISTS (
        SELECT 1 FROM #MatchItems mi
        JOIN TransactionJournalDetail td ON td.TxDetailId = mi.TxDetailId
        WHERE td.AccountId != @AccountId
    )
        THROW 50006, 'One or more transactions do not belong to the bank feed account.', 1;

    -- 5. Validate none are already matched
    IF EXISTS (
        SELECT 1 FROM #MatchItems mi
        JOIN BankFeedMatch bfm ON bfm.TxDetailId = mi.TxDetailId
    )
        THROW 50007, 'One or more transactions are already matched.', 1;

    -- 6. Validate none are locked/reconciled
    IF EXISTS (
        SELECT 1 FROM #MatchItems mi
        JOIN TransactionJournalDetail td ON td.TxDetailId = mi.TxDetailId
        JOIN TransactionJournal tj ON tj.TxId = td.TxId
        WHERE tj.IsLocked = 1
    )
        THROW 50008, 'One or more transactions are already locked/reconciled.', 1;

    -- 7. Amount validation
    DECLARE @SelectedTotal DECIMAL(18,2);

    SELECT @SelectedTotal = SUM(ISNULL(td.Amount, 0))
    FROM #MatchItems mi
    JOIN TransactionJournalDetail td ON td.TxDetailId = mi.TxDetailId;

    IF @SelectedTotal != @BankFeedAmount
        THROW 50005, 'Selected transaction total does not match the bank feed amount.', 1;

    -- 8. All validated - begin atomic changes
    BEGIN TRAN;
    BEGIN TRY

        -- Insert all match rows
        INSERT INTO BankFeedMatch (BankFeedTransactionId, TxId, TxDetailId)
        SELECT @BankFeedTransactionId, TxId, TxDetailId FROM #MatchItems;

        -- Update bank dates for each distinct TxId
        DECLARE @CurrentTxId BIGINT;
        DECLARE tx_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT DISTINCT TxId FROM #MatchItems;

        OPEN tx_cursor;
        FETCH NEXT FROM tx_cursor INTO @CurrentTxId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC [dbo].[Transaction_UpdateBankDate]
                @TxId = @CurrentTxId,
                @BankDate = @PostedDate,
                @ReferenceId = NULL,
                @PayeeId = NULL;

            FETCH NEXT FROM tx_cursor INTO @CurrentTxId;
        END

        CLOSE tx_cursor;
        DEALLOCATE tx_cursor;

        -- Update header
        UPDATE BankFeedTransaction
        SET Status = 'Matched',
            MatchedAt = SYSUTCDATETIME(),
            MatchedBy = @MatchedBy,
            ClearedBankDate = @PostedDate,
            ExcludeReason = NULL
        WHERE BankFeedTransactionId = @BankFeedTransactionId;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END

