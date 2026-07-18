-- ============================================================
-- BankFeed_GetAllList
-- 2026-07-09: fix amount search for formatted input. The amount
--   column casts to a plain number (e.g. 1912.78), so a term like
--   $1,912.78 never matched. Strip $ , and spaces into @AmtSearch
--   used ONLY for the amount comparison; text branches keep the
--   raw @Search so Description/Ref#/Check# searches are unchanged.
-- ============================================================


CREATE   PROCEDURE [dbo].[BankFeed_GetAllList]
    @Pageno INT,
    @Pagesize INT,
    @Search NVARCHAR(200),
    @StartDate DATE,
    @EndDate DATE,
    @AccountId INT,
    @Status VARCHAR(20),
    @AmountDirection VARCHAR(20),
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
        INSERT INTO #MatchTx EXEC dbo.Bank_TxDetail @AccountId;

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
    bft.ClearedBankDate,
    CASE
        WHEN bft.Status = ''Matched'' THEN ISNULL(mdet.MatchedCount, 0)
        ELSE ISNULL(tm.MatchCount, 0)
    END AS MatchCount,
    COALESCE(tm.MatchPayeeName, mdet.PayeeName)     AS MatchPayeeName,
    COALESCE(tm.MatchTxDate, mdet.TxDate)           AS MatchTxDate,
    COALESCE(tm.MatchAmount, mdet.Amount)           AS MatchAmount,
    COALESCE(tm.MatchReferenceId, mdet.ReferenceId) AS MatchReferenceId,
    COALESCE(tm.MatchSourceDocType, mdet.SourceDocType) AS MatchSourceDocType,
    tm.MatchCandidateTxId,
    tm.MatchCandidateTxDetailId'

    SET @Qry += ' FROM BankFeedTransaction AS bft
    JOIN BankFeedAccount AS bfa ON bfa.BankFeedAccountId = bft.BankFeedAccountId
    JOIN Account AS acct ON acct.AccountId = bfa.AccountId'

    IF @IsCount = 0
        SET @Qry += '
    OUTER APPLY (
        SELECT TOP 1 mt.PayeeName, mt.TxDate, mt.Amount, mt.ReferenceId, mt.SourceDocType,
               cnt.MatchedCount
        FROM BankFeedMatch bfm
        JOIN #MatchTx mt ON mt.TxDetailId = bfm.TxDetailId
        CROSS JOIN (
            SELECT COUNT(*) AS MatchedCount
            FROM BankFeedMatch
            WHERE BankFeedTransactionId = bft.BankFeedTransactionId
        ) cnt
        WHERE bfm.BankFeedTransactionId = bft.BankFeedTransactionId
          AND bft.Status = ''Matched''
        ORDER BY bfm.BankFeedMatchId
    ) mdet'

    IF @IsCount = 0 OR @Status = 'MatchFound'
        SET @Qry += '
    OUTER APPLY (
        SELECT
            COUNT(*) AS MatchCount,
            MAX(CASE WHEN ranked.rn = 1 THEN ranked.PayeeName END)   AS MatchPayeeName,
            MAX(CASE WHEN ranked.rn = 1 THEN ranked.TxDate END)       AS MatchTxDate,
            MAX(CASE WHEN ranked.rn = 1 THEN ranked.Amount END)        AS MatchAmount,
            MAX(CASE WHEN ranked.rn = 1 THEN ranked.ReferenceId END)   AS MatchReferenceId,
            MAX(CASE WHEN ranked.rn = 1 THEN ranked.SourceDocType END)   AS MatchSourceDocType,
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
                e.SourceDocType,
                ROW_NUMBER() OVER (
                    ORDER BY
                        CASE WHEN e.TxDate = bft.PostedDate AND e.Amount = bft.Amount THEN 0 ELSE 1 END,
                        ABS(DATEDIFF(DAY, e.TxDate, bft.PostedDate)),
                        ABS(ABS(e.Amount) - ABS(bft.Amount))
                ) AS rn
            FROM #MatchTx e
            WHERE bft.Status != ''Matched''
              AND e.IsLocked = 0
              AND e.TxDetailId NOT IN (SELECT TxDetailId FROM BankFeedMatch)
              AND (
                  CASE
                      WHEN bft.CheckNumber IS NOT NULL
                           AND EXISTS (
                               SELECT 1 FROM #MatchTx x
                               WHERE x.IsLocked = 0
                                 AND x.TxDetailId NOT IN (SELECT TxDetailId FROM BankFeedMatch)
                                 AND x.Amount = bft.Amount
                                 AND x.ReferenceId = bft.CheckNumber
                           )
                      THEN
                          CASE WHEN e.Amount = bft.Amount AND e.ReferenceId = bft.CheckNumber THEN 1 ELSE 0 END
                      ELSE
                          CASE WHEN (e.Amount = bft.Amount)
                               OR (bft.CheckNumber IS NOT NULL AND e.SourceDocNumber IS NOT NULL
                                   AND CAST(e.SourceDocNumber AS VARCHAR(50)) = bft.CheckNumber)
                               THEN 1 ELSE 0 END
                  END = 1
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

    IF @AmountDirection = 'MoneyIn'
        SET @Qry += ' AND bft.Amount > 0'
    ELSE IF @AmountDirection = 'MoneyOut'
        SET @Qry += ' AND bft.Amount < 0'

    IF @Search IS NOT NULL
    BEGIN
        -- 2026-07-09: strip currency formatting ($ , spaces) for the amount
        -- comparison only, so "$1,912.78" matches CAST(Amount)='1912.78'.
        -- Text branches keep the raw @Search.
        DECLARE @AmtSearch NVARCHAR(200) =
            REPLACE(REPLACE(REPLACE(@Search, '$', ''), ',', ''), ' ', '');

        SET @Qry += ' AND (bft.Description LIKE ''%' + @Search + '%'' OR bft.ReferenceNo LIKE ''%' + @Search + '%'' OR bft.CheckNumber LIKE ''%' + @Search + '%'''

        IF @AmtSearch <> ''
            SET @Qry += ' OR CAST(bft.Amount AS VARCHAR(50)) LIKE ''%' + @AmtSearch + '%'''

        SET @Qry += ')'
    END

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

