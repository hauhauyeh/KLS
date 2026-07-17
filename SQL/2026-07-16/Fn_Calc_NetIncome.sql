SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- FIX_ICREDIT_AMOUNT_SIGN 2026-07-16: net income now sums CrDeAmount (balanced, normal-side-adjusted) over I/X/C, not Amount. Decouples from the posting Amount-sign fix. See baseline.

CREATE OR ALTER PROCEDURE [dbo].[Fn_Calc_NetIncome]
    @BeginDate DATE,
    @EndDate   DATE,
    @NetIncome DECIMAL(18,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- 2026-07-16 FIX_ICREDIT_AMOUNT_SIGN: net income now sums CrDeAmount (the balanced,
    -- normal-side-adjusted value: credit +, debit -). Income credits add, expense/COGS debits
    -- subtract, contra accounts (e.g. @ICREDIT, @IDG) self-handle by their own sign -- no CASE,
    -- no IsAccountDebit branching, no Amount. Same result today; stays correct after the
    -- Sales_Insert / Sales_PartialUpdate Amount-sign fix. Date filter widened to a half-open
    -- range (>= begin, < end+1) so an end-of-day time component can't drop rows.
    SELECT @NetIncome = ISNULL(SUM(td.CrDeAmount), 0)
    FROM dbo.TransactionJournalDetail td
    INNER JOIN dbo.TransactionJournal t
        ON t.TxId = td.TxId
    INNER JOIN dbo.Account a
        ON a.AccountId = td.AccountId
    INNER JOIN dbo.AccountCategory ac
        ON ac.AccountCategoryId = a.AccountCategoryId
    WHERE t.TxDate >= @BeginDate
      AND t.TxDate < DATEADD(DAY, 1, @EndDate)
      AND ac.ClassCode IN ('I','X','C');   -- I = Income, X = Expense, C = COGS

    -- OLD (Amount-based; coupled to the @ICREDIT Amount-sign bug, breaks when it is fixed):
    -- DECLARE @Income DECIMAL(18,2) = 0, @Expense DECIMAL(18,2) = 0;
    -- ;WITH TxData AS (
    --     SELECT td.Amount, ac.ClassCode, a.IsAccountDebit
    --     FROM dbo.TransactionJournalDetail td
    --     INNER JOIN dbo.TransactionJournal t   ON t.TxId = td.TxId
    --     INNER JOIN dbo.Account a              ON a.AccountId = td.AccountId
    --     INNER JOIN dbo.AccountCategory ac     ON ac.AccountCategoryId = a.AccountCategoryId
    --     WHERE t.TxDate BETWEEN @BeginDate AND @EndDate AND ac.ClassCode IN ('I','X','C') )
    -- SELECT @Income  = SUM(CASE WHEN ClassCode = 'I' THEN Amount ELSE 0 END),
    --        @Expense = SUM(CASE WHEN ClassCode IN ('X','C') AND IsAccountDebit = 1 THEN Amount
    --                            WHEN ClassCode IN ('X','C') AND IsAccountDebit = 0 THEN -Amount
    --                            ELSE 0 END)
    -- FROM TxData;
    -- SET @NetIncome = ISNULL(@Income, 0) - ISNULL(@Expense, 0);
END

