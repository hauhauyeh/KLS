-- =============================================================================================
-- BankFeed_UnMatchTx  (MODIFIED)  — bank-feed-retire-legacy-matched-columns-v1
-- Change vs 2026-07-06 version: the header reset UPDATE no longer sets the legacy
-- MatchedTxId / MatchedTxDetailId columns (they are being dropped from BankFeedTransaction;
-- the BankFeedMatch junction table has been the source of truth since 2026-06-11).
-- Everything else — the #TxIds capture, per-Tx BankDate clear, and the
-- BankRecon_RecalcByAccount cascade (bank-recon-auto-difference-v1) — is unchanged.
--
-- Deploy this BEFORE BankFeed_RetireLegacyMatchColumns.sql, so no live SP references the
-- columns at the moment they are dropped.
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

        -- Reset the bank feed header back to Pending
        UPDATE BankFeedTransaction
        SET ClearedBankDate = NULL,
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
