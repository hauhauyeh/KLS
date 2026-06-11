SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [dbo].[BankFeed_GetMatchTxList]
    @BankFeedTransactionId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccountId INT,
            @PostedDate DATE,
            @Amount DECIMAL(18,2),
            @CheckNumber VARCHAR(50);

    SELECT @AccountId   = bfa.AccountId,
           @PostedDate  = bft.PostedDate,
           @Amount      = bft.Amount,
           @CheckNumber = bft.CheckNumber
    FROM BankFeedTransaction bft
    JOIN BankFeedAccount bfa ON bfa.BankFeedAccountId = bft.BankFeedAccountId
    WHERE bft.BankFeedTransactionId = @BankFeedTransactionId;

    IF @AccountId IS NULL
        RETURN;

    CREATE TABLE #EnrichedTx
    (
        [TxDetailId] BIGINT NULL,
        [TxId] BIGINT NULL,
        [TxDate] DATE NULL,
        [SourceDocType] NVARCHAR(100) NULL,
        [SourceDocNumber] INT NULL,
        [Amount] DECIMAL(18,2) NULL,
        [IsLocked] BIT NULL DEFAULT ((0)),
        [BankDate] DATE NULL,
        [PayeeName] NVARCHAR(255) NULL,
        [ReferenceId] NVARCHAR(255) NULL,
        [PayeeId] INT NULL,
        [IsVoid] BIT,
        [PaymentMethod] NVARCHAR(255) NULL
    );

    INSERT INTO #EnrichedTx EXEC dbo.sp_TxDetailEnriched @AccountId;

    -- TxDetailIds already matched by other bank feed rows
    ;WITH AlreadyMatched AS (
        SELECT MatchedTxDetailId
        FROM BankFeedTransaction
        WHERE Status = 'Matched'
          AND BankFeedTransactionId != @BankFeedTransactionId
          AND MatchedTxDetailId IS NOT NULL
    )

    SELECT
        e.TxDetailId,
        e.TxId,
        e.TxDate,
        e.SourceDocType,
        e.SourceDocNumber,
        ISNULL(e.Amount, 0) AS Amount,
        e.ReferenceId,
        e.PayeeName
    FROM #EnrichedTx e
    WHERE e.IsLocked = 0
      AND e.TxDetailId NOT IN (SELECT MatchedTxDetailId FROM AlreadyMatched)
    ORDER BY
        CASE WHEN ISNULL(e.Amount, 0) = @Amount THEN 0 ELSE 1 END,
        CASE WHEN e.TxDate = @PostedDate AND ISNULL(e.Amount, 0) = @Amount THEN 0 ELSE 1 END,
        ABS(DATEDIFF(DAY, e.TxDate, @PostedDate)),
        ABS(ABS(ISNULL(e.Amount, 0)) - ABS(@Amount))
END
GO
