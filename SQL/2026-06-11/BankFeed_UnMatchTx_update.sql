SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [dbo].[BankFeed_UnMatchTx]
    @BankFeedTransactionId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Capture all matched TxIds before deleting
    SELECT DISTINCT TxId
    INTO #TxIds
    FROM BankFeedMatch
    WHERE BankFeedTransactionId = @BankFeedTransactionId;

    IF NOT EXISTS (SELECT 1 FROM #TxIds)
        RETURN;

    BEGIN TRAN;
    BEGIN TRY

        -- Delete match rows first
        DELETE FROM BankFeedMatch
        WHERE BankFeedTransactionId = @BankFeedTransactionId;

        -- Clear BankDate only for TxIds that have no remaining matches
        DECLARE @CurrentTxId BIGINT;
        DECLARE tx_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT TxId FROM #TxIds;

        OPEN tx_cursor;
        FETCH NEXT FROM tx_cursor INTO @CurrentTxId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM BankFeedMatch WHERE TxId = @CurrentTxId)
            BEGIN
                EXEC [dbo].[Transaction_UpdateBankDate]
                    @TxId = @CurrentTxId,
                    @BankDate = NULL,
                    @ReferenceId = NULL,
                    @PayeeId = NULL;
            END

            FETCH NEXT FROM tx_cursor INTO @CurrentTxId;
        END

        CLOSE tx_cursor;
        DEALLOCATE tx_cursor;

        -- Clear legacy columns
        UPDATE BankFeedTransaction
        SET MatchedTxId = NULL,
            MatchedTxDetailId = NULL,
            ClearedBankDate = NULL,
            Status = 'Pending',
            MatchedAt = NULL,
            MatchedBy = NULL
        WHERE BankFeedTransactionId = @BankFeedTransactionId;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
