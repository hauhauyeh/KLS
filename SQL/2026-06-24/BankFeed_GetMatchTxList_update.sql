SET QUOTED_IDENTIFIER ON
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

    INSERT INTO #EnrichedTx EXEC dbo.Bank_TxDetail @AccountId;

    ;WITH AlreadyMatched AS (
        SELECT TxDetailId
        FROM BankFeedMatch
        WHERE BankFeedTransactionId != @BankFeedTransactionId
    )
    SELECT TxDetailId INTO #Available
    FROM #EnrichedTx e
    WHERE e.IsLocked = 0
      AND e.TxDetailId NOT IN (SELECT TxDetailId FROM AlreadyMatched);

    DECLARE @StrictMatchCount INT;
    SELECT @StrictMatchCount = COUNT(*)
    FROM #EnrichedTx e
    JOIN #Available a ON a.TxDetailId = e.TxDetailId
    WHERE (e.Amount = @Amount)
       OR (@CheckNumber IS NOT NULL AND e.ReferenceId IS NOT NULL
           AND e.ReferenceId = @CheckNumber);

    IF @StrictMatchCount > 0
    BEGIN
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
        JOIN #Available a ON a.TxDetailId = e.TxDetailId
        WHERE (e.Amount = @Amount)
           OR (@CheckNumber IS NOT NULL AND e.ReferenceId IS NOT NULL
               AND e.ReferenceId = @CheckNumber)
        ORDER BY
            CASE WHEN e.TxDate = @PostedDate AND e.Amount = @Amount THEN 0 ELSE 1 END,
            ABS(DATEDIFF(DAY, e.TxDate, @PostedDate)),
            ABS(ABS(e.Amount) - ABS(@Amount))
    END
    ELSE
    BEGIN
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
        JOIN #Available a ON a.TxDetailId = e.TxDetailId
        ORDER BY
            CASE WHEN e.Amount = @Amount THEN 0 ELSE 1 END,
            CASE WHEN e.TxDate = @PostedDate AND e.Amount = @Amount THEN 0 ELSE 1 END,
            ABS(DATEDIFF(DAY, e.TxDate, @PostedDate)),
            ABS(ABS(e.Amount) - ABS(@Amount))
    END
END
GO
