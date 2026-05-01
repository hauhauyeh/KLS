CREATE OR ALTER PROCEDURE [dbo].[Report_ProfitLoss]
    @StartDate DATE,
    @EndDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Expense   MONEY = 0;
    DECLARE @Income    MONEY = 0;
    DECLARE @Inventory MONEY = 0;
    DECLARE @Profit    MONEY = 0;

    CREATE TABLE #ReportPL
    (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        ClassCode       CHAR(1),
        ClassName       NVARCHAR(50),
        CategoryLevel0  NVARCHAR(255),
        CategoryLevel1  NVARCHAR(255),
        CategoryLevel2  NVARCHAR(255),
        CategoryLevel3  NVARCHAR(255),
        AccountId       INT,
        AccountCode     NVARCHAR(50),
        AccountName     NVARCHAR(255),
        AcctBalance     DECIMAL(18,2) NOT NULL DEFAULT(0),
        IsAccountDebit  BIT
    );

    INSERT INTO #ReportPL
    (
        ClassCode, ClassName,
        CategoryLevel0, CategoryLevel1, CategoryLevel2, CategoryLevel3,
        AccountId, AccountCode, AccountName,
        AcctBalance, IsAccountDebit
    )
    SELECT
        ct.ClassCode,
        ct.ClassName,
        ct.Level0,
        ct.Level1,
        ct.Level2,
        ct.Level3,
        a.AccountId,
        a.AccountCode,
        a.AccountName,
        CAST(0 AS MONEY),
        a.IsAccountDebit
    FROM dbo.Account a
    INNER JOIN View_AccountTree ct
        ON a.AccountCategoryId = ct.AccountCategoryId
    WHERE a.Inactive = 0
      AND ct.ClassCode IN ('I','X','C');

    ;WITH Bal AS
    (
        SELECT
            r.AccountId,
            SUM(td.Amount) AS Amount
        FROM #ReportPL r
        INNER JOIN dbo.TransactionJournalDetail td
            ON td.AccountId = r.AccountId
        INNER JOIN dbo.TransactionJournal t
            ON t.TxId = td.TxId
        WHERE t.TxDate >= @StartDate
          AND t.TxDate < DATEADD(DAY, 1, @EndDate)
        GROUP BY r.AccountId
    )
    UPDATE r
    SET r.AcctBalance = ISNULL(b.Amount, 0)
    FROM #ReportPL r
    LEFT JOIN Bal b
        ON b.AccountId = r.AccountId;

    UPDATE #ReportPL
    SET AcctBalance = AcctBalance * -1
    WHERE ClassCode = 'C'
      AND IsAccountDebit = 0;

    UPDATE #ReportPL
    SET ClassCode = 'V',
        ClassName = 'Inventory Adj',
        CategoryLevel0 = 'INVENTORY ADJ',
        CategoryLevel1 = NULL,
        CategoryLevel2 = NULL
    WHERE AccountCode IN ('@IINVG', '@EINVL');

    UPDATE #ReportPL
    SET AcctBalance = AcctBalance * -1
    WHERE AccountCode = '@EINVL';

    SELECT @Expense = ISNULL(SUM(AcctBalance), 0)
    FROM #ReportPL
    WHERE ClassCode = 'X';

    SELECT @Income = ISNULL(SUM(AcctBalance), 0)
    FROM #ReportPL
    WHERE ClassCode IN ('I', 'C');

    SELECT @Inventory = ISNULL(SUM(AcctBalance), 0)
    FROM #ReportPL
    WHERE ClassCode = 'V';

    SET @Profit = @Income - @Expense + @Inventory;

    INSERT INTO #ReportPL
    (
        ClassCode, ClassName,
        CategoryLevel0, CategoryLevel1, CategoryLevel2, CategoryLevel3,
        AccountId, AccountCode, AccountName,
        AcctBalance, IsAccountDebit
    )
    SELECT
        ct.ClassCode,
        ct.ClassName,
        ct.Level0,
        ct.Level1,
        ct.Level2,
        ct.Level3,
        a.AccountId,
        a.AccountCode,
        a.AccountName,
        @Profit,
        a.IsAccountDebit
    FROM dbo.Account a
    INNER JOIN View_AccountTree ct
        ON a.AccountCategoryId = ct.AccountCategoryId
    WHERE ct.IsActive = 1
      AND a.Inactive = 0
      AND a.AccountCode = '@NET';

    SELECT
        ClassCode, ClassName,
        CategoryLevel0, CategoryLevel1, CategoryLevel2, CategoryLevel3,
        AccountId, AccountCode, AccountName,
        AcctBalance
    FROM #ReportPL
    WHERE ISNULL(AcctBalance, 0) <> 0
    ORDER BY
        CASE
            WHEN ClassCode = 'I' THEN 1
            WHEN ClassCode = 'C' THEN 2
            WHEN ClassCode = 'X' THEN 3
            WHEN ClassCode = 'V' THEN 4
            WHEN AccountCode = '@NET' THEN 5
            ELSE 9
        END,
        CategoryLevel0, CategoryLevel1, CategoryLevel2, CategoryLevel3,
        AccountCode;

    DROP TABLE #ReportPL;
END
