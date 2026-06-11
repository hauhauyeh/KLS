SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [dbo].[BankFeed_GetAllList]
    @Pageno INT,
    @Pagesize INT,
    @Search NVARCHAR(200),
    @StartDate DATE,
    @EndDate DATE,
    @AccountId INT,
    @Status VARCHAR(20),
    @SortField NVARCHAR(50),
    @SortOrder NVARCHAR(50),
    @IsCount BIT,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Populate enriched transactions for match candidate lookup
    CREATE TABLE #MatchTx
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

    IF @AccountId IS NOT NULL AND (@IsCount = 0 OR @Status = 'MatchFound')
        INSERT INTO #MatchTx EXEC dbo.sp_TxDetailEnriched @AccountId;

    DECLARE @Qry NVARCHAR(MAX);

    IF @IsCount = 1
        SET @Qry = 'SELECT @RCount = COUNT(*)'
    ELSE
        SET @Qry = 'SELECT
    bft.BankFeedTransactionId,
    bft.BankFeedAccountId,
    bfa.AccountId,
    acct.AccountName,
    bft.ImportBatchId,
    bft.RowNo,
    bft.PostedDate,
    bft.Amount,
    bft.Description,
    bft.ReferenceNo,
    bft.CheckNumber,
    bft.Balance,
    bft.Status,
    bft.MatchedTxId,
    bft.MatchedTxDetailId,
    bft.ClearedBankDate,
    tx.SourceDocType AS MatchedSourceDocType,
    tx.SourceDocNumber AS MatchedSourceDocNumber,
    tx.TxDate AS MatchedTxDate,
    CASE WHEN bft.MatchedTxDetailId IS NOT NULL THEN 1 ELSE ISNULL(tm.MatchCount, 0) END AS MatchCount,
    COALESCE(tm.MatchPayeeName, mtx.PayeeName)     AS MatchPayeeName,
    COALESCE(tm.MatchTxDate, mtx.TxDate)           AS MatchTxDate,
    COALESCE(tm.MatchAmount, mtx.Amount)           AS MatchAmount,
    COALESCE(tm.MatchReferenceId, mtx.ReferenceId) AS MatchReferenceId,
    tm.MatchCandidateTxId,
    tm.MatchCandidateTxDetailId'

    SET @Qry += ' FROM BankFeedTransaction AS bft
    JOIN BankFeedAccount AS bfa ON bfa.BankFeedAccountId = bft.BankFeedAccountId
    JOIN Account AS acct ON acct.AccountId = bfa.AccountId
    LEFT JOIN TransactionJournal AS tx ON tx.TxId = bft.MatchedTxId
    LEFT JOIN #MatchTx AS mtx ON mtx.TxDetailId = bft.MatchedTxDetailId'

    IF @IsCount = 0 OR @Status = 'MatchFound'
        SET @Qry += '
    OUTER APPLY (
        SELECT
            COUNT(*) AS MatchCount,
            MAX(CASE WHEN ranked.rn = 1 THEN ranked.PayeeName END)   AS MatchPayeeName,
            MAX(CASE WHEN ranked.rn = 1 THEN ranked.TxDate END)       AS MatchTxDate,
            MAX(CASE WHEN ranked.rn = 1 THEN ranked.Amount END)        AS MatchAmount,
            MAX(CASE WHEN ranked.rn = 1 THEN ranked.ReferenceId END)   AS MatchReferenceId,
            MAX(CASE WHEN ranked.rn = 1 THEN ranked.TxId END)          AS MatchCandidateTxId,
            MAX(CASE WHEN ranked.rn = 1 THEN ranked.TxDetailId END)    AS MatchCandidateTxDetailId
        FROM (
            SELECT
                e.TxId,
                e.TxDetailId,
                e.PayeeName,
                e.TxDate,
                e.Amount,
                e.ReferenceId,
                ROW_NUMBER() OVER (
                    ORDER BY
                        CASE WHEN e.TxDate = bft.PostedDate AND e.Amount = bft.Amount THEN 0 ELSE 1 END,
                        ABS(DATEDIFF(DAY, e.TxDate, bft.PostedDate)),
                        ABS(ABS(e.Amount) - ABS(bft.Amount))
                ) AS rn
            FROM #MatchTx e
            WHERE bft.Status != ''Matched''
              AND e.IsLocked = 0
              AND e.TxDetailId NOT IN (
                  SELECT MatchedTxDetailId FROM BankFeedTransaction
                  WHERE Status = ''Matched'' AND MatchedTxDetailId IS NOT NULL
              )
              AND (
                  (e.Amount = bft.Amount)
                  OR (bft.CheckNumber IS NOT NULL AND e.SourceDocNumber IS NOT NULL
                      AND CAST(e.SourceDocNumber AS VARCHAR(50)) = bft.CheckNumber)
              )
        ) ranked
    ) tm'

    SET @Qry += ' WHERE 1=1'

    IF @AccountId IS NOT NULL
        SET @Qry += ' AND bfa.AccountId = ' + CAST(@AccountId AS VARCHAR)

    IF @Status = 'MatchFound'
        SET @Qry += ' AND bft.Status = ''Pending'' AND tm.MatchCount > 0'
    ELSE IF @Status IS NOT NULL AND @Status != 'All'
        SET @Qry += ' AND bft.Status = ''' + @Status + ''''

    IF @Search IS NOT NULL
        SET @Qry += ' AND (bft.Description LIKE ''%' + @Search + '%'' OR bft.ReferenceNo LIKE ''%' + @Search + '%'' OR bft.CheckNumber LIKE ''%' + @Search + '%'' OR CAST(bft.Amount AS VARCHAR(50)) LIKE ''%' + @Search + '%'')'

    IF @StartDate IS NOT NULL
        SET @Qry += ' AND bft.PostedDate >= ''' + CONVERT(VARCHAR, @StartDate) + ''''

    IF @EndDate IS NOT NULL
        SET @Qry += ' AND bft.PostedDate <= ''' + CONVERT(VARCHAR, @EndDate) + ''''

    IF @IsCount = 1
    BEGIN
        EXEC sp_executesql @Qry, N'@RCount INT OUTPUT', @RCount = @TotalCount OUTPUT
        RETURN
    END

    IF @SortField IS NOT NULL
        SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder
    ELSE
        SET @Qry += ' ORDER BY bft.PostedDate DESC, bft.BankFeedTransactionId DESC'

    SET @Qry += ' OFFSET ' + CONVERT(VARCHAR(100), (@Pagesize * (@Pageno - 1))) + ' ROWS
    FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY'

    EXEC (@Qry)
END
GO
