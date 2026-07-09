-- =============================================================================================
-- BankFeed_UnMatchTx  (MODIFIED)  — bank-recon-auto-difference-v1
-- Change vs baseline: capture the affected AccountId + ClearedBankDate BEFORE the header UPDATE nulls
-- ClearedBankDate, then after the header reset and BEFORE COMMIT TRAN call BankRecon_RecalcByAccount so
-- the stored BankRecon.DifferenceAmount returns to its pre-match value (the unmatched line drops back
-- out of the recon window). Runs inside the existing atomic transaction (SET XACT_ABORT ON + TRY/CATCH).
-- @FromDate NULL (e.g. ClearedBankDate already null) => RecalcByAccount recomputes the whole account.
-- Everything else is identical to the baseline.
-- =============================================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[BankFeed_UnMatchTx]
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

    -- bank-recon-auto-difference-v1: capture the affected account + cleared date NOW, before the
    -- header UPDATE below nulls ClearedBankDate. Used to cascade the recon recompute after unmatch.
    DECLARE @AccountId INT, @FromDate DATE;
    SELECT @AccountId = bfa.AccountId,
           @FromDate  = bft.ClearedBankDate
    FROM BankFeedTransaction bft
    JOIN BankFeedAccount bfa ON bfa.BankFeedAccountId = bft.BankFeedAccountId
    WHERE bft.BankFeedTransactionId = @BankFeedTransactionId;

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

        -- bank-recon-auto-difference-v1: refresh the stored recon difference for this account,
        -- cascading from the (now removed) cleared date forward, inside the same atomic transaction.
        IF @AccountId IS NOT NULL
            EXEC [dbo].[BankRecon_RecalcByAccount]
                @AccountId = @AccountId,
                @FromDate  = @FromDate;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
