
CREATE PROCEDURE [dbo].[Fn_Calc_NetIncome]
    @BeginDate DATE,
    @EndDate   DATE,
    @NetIncome DECIMAL(18,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @Income  DECIMAL(18,2) = 0,
        @Expense DECIMAL(18,2) = 0;

    ;WITH TxData AS
    (
        SELECT
            td.Amount,
            ac.ClassCode,
            a.IsAccountDebit
        FROM dbo.TransactionJournalDetail td
        INNER JOIN dbo.TransactionJournal t
            ON t.TxId = td.TxId
        INNER JOIN dbo.Account a
            ON a.AccountId = td.AccountId
        INNER JOIN dbo.AccountCategory ac
            ON ac.AccountCategoryId = a.AccountCategoryId
        WHERE t.TxDate BETWEEN @BeginDate AND @EndDate
          AND ac.ClassCode IN ('I','X','C')   -- I = Income, X = Expense, C = COGS
    )
    SELECT
        @Income  = SUM(CASE WHEN ClassCode = 'I' THEN Amount ELSE 0 END),
        @Expense = SUM(CASE
                        WHEN ClassCode IN ('X','C') AND IsAccountDebit = 1 THEN Amount
                        WHEN ClassCode IN ('X','C') AND IsAccountDebit = 0 THEN -Amount
                        ELSE 0 END)
    FROM TxData;

    SET @NetIncome = ISNULL(@Income, 0) - ISNULL(@Expense, 0);
END

