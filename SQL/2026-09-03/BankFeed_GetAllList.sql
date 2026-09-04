SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- BankFeed_GetAllList
-- 2026-09-03 bank-feed-status-rule-mark-flow: keep stored bank-feed statuses
--   limited to Pending/Matched/Excluded while adding derived filter support for
--   AllOpen, RuleSuggested, and RuleApplied. MatchFound remains the backend
--   filter alias for "Pending rows with match candidates"; UI may label it
--   Review Match. Active suggestions and applied suggestions use separate
--   OUTER APPLY blocks so Applied history does not hide open suggestion state.
-- ============================================================
-- 2026-08-20 bank-feed-rule-safe-apply: add nullable rule suggestion summary fields
--   to the non-count list projection only. The count branch stays unchanged.
--   Suggestion status is display-only here; apply is revalidated by the backend.
--   Applyable means one active Suggested row whose action is Exclude, a money-out
--   expense with payee/account IDs, a money-in deposit with an account ID, or a
--   transfer with a target account ID.
-- ============================================================
-- 2026-07-27 bank-feed-create-phase-1: add IsGenerated to the row projection.
--   1 when an Active BankFeedSource exists for the row, i.e. Bank Feed created the
--   transaction itself rather than matching one that already existed.
--   The list uses it to show [Reverse] instead of [Unmatch] - deleting a payment and
--   detaching a link are different enough that they must not share a button.
--   Added to the non-count branch only; the count branch selects COUNT(*) and never
--   projects columns. Deploy AFTER BankFeedSource_create.sql - this references the table.
--   CAST(... AS BIT) is required: BankFeedTransactionList.IsGenerated is a bool, and a bare
--   CASE returns INT, which fails the FromSqlRaw projection with
--   "Unable to cast object of type 'System.Int32' to type 'System.Boolean'".
--   See baseline: KLS/SQL/2026-07-27/BankFeed_GetAllList_live_baseline.sql
-- ============================================================
-- FIX_CHECKNUM_CONFLICT 2026-07-17: the match-candidate fallback branch (used when no
--   exact check#+amount pair exists in the books) matched on AMOUNT ALONE, so a bank
--   check row could be suggested against a book payment carrying a DIFFERENT check
--   number. Repro: bank row 1305 (check #22562, -450.00) suggested "1 match found" =
--   Bill Payment New Marco Food 04/20/26 -450.00 check #22472, because check 22562 was
--   never recorded in the books and the fallback ignored ReferenceId entirely.
--   Fix: when the bank row has a CheckNumber, the amount-only fallback now EXCLUDES
--   candidates whose ReferenceId is a different (non-empty) value; candidates with no
--   reference recorded (NULL/blank, e.g. ACH) still match on amount, and the
--   SourceDocNumber-equals-check# alternative is unchanged. Strict branch unchanged.
--   Result for the repro row: 0 matches (correct -- check 22562 is not in the books).
-- See baseline: KLS/SQL/2026-07-17/BankFeed_GetAllList_live_baseline.sql
-- ============================================================
-- 2026-07-09: fix amount search for formatted input. The amount
--   column casts to a plain number (e.g. 1912.78), so a term like
--   $1,912.78 never matched. Strip $ , and spaces into @AmtSearch
--   used ONLY for the amount comparison; text branches keep the
--   raw @Search so Description/Ref#/Check# searches are unchanged.
-- ============================================================


CREATE OR ALTER PROCEDURE [dbo].[BankFeed_GetAllList]
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

    IF @AccountId IS NOT NULL AND (@IsCount = 0 OR @Status IN ('Pending', 'MatchFound'))
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
    tm.MatchCandidateTxDetailId,
    CAST(CASE WHEN EXISTS (
        SELECT 1 FROM BankFeedSource bfs
        WHERE bfs.BankFeedTransactionId = bft.BankFeedTransactionId
          AND bfs.Status = ''Active''
    ) THEN 1 ELSE 0 END AS BIT) AS IsGenerated,
    COALESCE(rs.BankFeedRuleSuggestionId, ars.BankFeedRuleSuggestionId) AS BankFeedRuleSuggestionId,
    COALESCE(rs.SuggestionStatus, ars.SuggestionStatus) AS RuleSuggestionStatus,
    ISNULL(rs.RuleSuggestionCount, CASE WHEN ars.BankFeedRuleSuggestionId IS NULL THEN 0 ELSE 1 END) AS RuleSuggestionCount,
    COALESCE(rs.RuleName, ars.RuleName) AS RuleSuggestionName,
    COALESCE(rs.ActionType, ars.ActionType) AS RuleSuggestionActionType,
    COALESCE(rs.PayeeName, ars.PayeeName) AS RuleSuggestionPayeeName,
    COALESCE(rs.AccountName, ars.AccountName) AS RuleSuggestionAccountName,
    COALESCE(rs.TargetAccountName, ars.TargetAccountName) AS RuleSuggestionTargetAccountName,
    CAST(CASE
        WHEN rs.SuggestionStatus = ''Suggested''
             AND (
                 rs.ActionType = ''Exclude''
                 OR (rs.ActionType = ''CreateMoneyOutExpense''
                     AND rs.PayeeId IS NOT NULL
                     AND rs.AccountId IS NOT NULL)
                 OR (rs.ActionType = ''CreateMoneyInDeposit''
                     AND rs.AccountId IS NOT NULL)
                 OR (rs.ActionType = ''CreateTransfer''
                     AND rs.TargetAccountId IS NOT NULL)
             )
        THEN 1 ELSE 0
    END AS BIT) AS IsRuleSuggestionApplyable'

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

    IF @IsCount = 0 OR @Status IN ('Pending', 'MatchFound')
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
                          -- 2026-07-17 FIX_CHECKNUM_CONFLICT: amount-only fallback must not
                          -- suggest a candidate carrying a DIFFERENT check number than the bank
                          -- row. Candidates with no reference (NULL/blank, e.g. ACH) still match.
                          -- OLD: CASE WHEN (e.Amount = bft.Amount)
                          CASE WHEN (e.Amount = bft.Amount
                                     AND (bft.CheckNumber IS NULL
                                          OR e.ReferenceId IS NULL
                                          OR LTRIM(RTRIM(e.ReferenceId)) = ''''
                                          OR e.ReferenceId = bft.CheckNumber))
                               OR (bft.CheckNumber IS NOT NULL AND e.SourceDocNumber IS NOT NULL
                                   AND CAST(e.SourceDocNumber AS VARCHAR(50)) = bft.CheckNumber)
                               THEN 1 ELSE 0 END
                  END = 1
              )
        ) ranked
    ) tm'

    IF @IsCount = 0 OR @Status IN ('Pending', 'RuleSuggested')
        SET @Qry += '
    OUTER APPLY (
        SELECT TOP 1
            s.BankFeedRuleSuggestionId,
            s.SuggestionStatus,
            cnt.RuleSuggestionCount,
            r.RuleName,
            a.ActionType,
            a.PayeeId,
            a.AccountId,
            a.TargetAccountId,
            p.PayeeName,
            actionAcct.AccountName,
            targetAcct.AccountName AS TargetAccountName
        FROM BankFeedRuleSuggestion s
        JOIN BankFeedRule r ON r.BankFeedRuleId = s.BankFeedRuleId
        LEFT JOIN BankFeedRuleAction a ON a.BankFeedRuleId = r.BankFeedRuleId
        LEFT JOIN Payee p ON p.PayeeId = a.PayeeId
        LEFT JOIN Account actionAcct ON actionAcct.AccountId = a.AccountId
        LEFT JOIN Account targetAcct ON targetAcct.AccountId = a.TargetAccountId
        CROSS JOIN (
            SELECT COUNT(*) AS RuleSuggestionCount
            FROM BankFeedRuleSuggestion sx
            WHERE sx.BankFeedTransactionId = bft.BankFeedTransactionId
              AND sx.SuggestionStatus IN (''Suggested'', ''Conflict'', ''MissingSetup'')
        ) cnt
        WHERE s.BankFeedTransactionId = bft.BankFeedTransactionId
          AND s.SuggestionStatus IN (''Suggested'', ''Conflict'', ''MissingSetup'')
        ORDER BY
            CASE WHEN s.IsPreferred = 1 THEN 0 ELSE 1 END,
            r.Priority,
            s.Score DESC,
            s.BankFeedRuleSuggestionId
    ) rs'

    IF @IsCount = 0 OR @Status IN ('Matched', 'RuleApplied')
        SET @Qry += '
    OUTER APPLY (
        SELECT TOP 1
            s.BankFeedRuleSuggestionId,
            s.SuggestionStatus,
            r.RuleName,
            a.ActionType,
            p.PayeeName,
            actionAcct.AccountName,
            targetAcct.AccountName AS TargetAccountName
        FROM BankFeedRuleSuggestion s
        JOIN BankFeedRule r ON r.BankFeedRuleId = s.BankFeedRuleId
        LEFT JOIN BankFeedRuleAction a ON a.BankFeedRuleId = r.BankFeedRuleId
        LEFT JOIN Payee p ON p.PayeeId = a.PayeeId
        LEFT JOIN Account actionAcct ON actionAcct.AccountId = a.AccountId
        LEFT JOIN Account targetAcct ON targetAcct.AccountId = a.TargetAccountId
        WHERE s.BankFeedTransactionId = bft.BankFeedTransactionId
          AND s.SuggestionStatus = ''Applied''
        ORDER BY
            s.AppliedAt DESC,
            s.BankFeedRuleSuggestionId DESC
    ) ars'

    SET @Qry += ' WHERE 1=1'

    IF @AccountId IS NOT NULL
        SET @Qry += ' AND bfa.AccountId = ' + CAST(@AccountId AS VARCHAR)

    IF @Status = 'AllOpen'
        SET @Qry += ' AND bft.Status = ''Pending'''
    ELSE IF @Status = 'Pending'
        SET @Qry += ' AND bft.Status = ''Pending'' AND ISNULL(tm.MatchCount, 0) = 0 AND rs.BankFeedRuleSuggestionId IS NULL'
    ELSE IF @Status = 'MatchFound'
        SET @Qry += ' AND bft.Status = ''Pending'' AND tm.MatchCount > 0'
    ELSE IF @Status = 'RuleSuggested'
        SET @Qry += ' AND rs.SuggestionStatus = ''Suggested'''
    ELSE IF @Status = 'RuleApplied'
        SET @Qry += ' AND ars.BankFeedRuleSuggestionId IS NOT NULL'
    ELSE IF @Status = 'Matched'
        SET @Qry += ' AND bft.Status = ''Matched'' AND ars.BankFeedRuleSuggestionId IS NULL'
    ELSE IF @Status = 'Excluded'
        SET @Qry += ' AND bft.Status = ''Excluded'''
    ELSE IF @Status IS NOT NULL AND @Status != 'All'
        SET @Qry += ' AND 1 = 0'

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
