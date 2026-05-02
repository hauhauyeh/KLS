-- Rename existing SP
EXEC sp_rename 'Report_BalanceSheet', 'Report_BalanceSheet_prev';
GO

CREATE PROCEDURE [dbo].[Report_BalanceSheet]  -- Exec dbo.Report_BalanceSheet '2026-01-20'
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @EndDate IS NULL
        SET @EndDate = GETDATE()

    DECLARE @BeginDate DATE = DATEFROMPARTS(YEAR(@EndDate), 1, 1);
    DECLARE @NetIncome DECIMAL(18,2);

    -------------------------------------------------------------------
    -- 1) CTE with sort columns at each hierarchy level
    -------------------------------------------------------------------
    ;WITH CatTree AS
    (
        SELECT
            c.AccountCategoryId,
            c.ParentId,
            c.CategoryName,
            c.ClassCode,
            c.ClassName,
            c.SortOrder,
            c.IsActive,
            0 AS Lvl,
            CAST(c.CategoryName AS NVARCHAR(255)) AS Level0,
            CAST(NULL AS NVARCHAR(255)) AS Level1,
            CAST(NULL AS NVARCHAR(255)) AS Level2,
            CAST(NULL AS NVARCHAR(255)) AS Level3,
            c.SortOrder AS Sort0,
            CAST(NULL AS INT) AS Sort1,
            CAST(NULL AS INT) AS Sort2,
            CAST(NULL AS INT) AS Sort3
        FROM dbo.AccountCategory c
        WHERE c.ParentId IS NULL

        UNION ALL

        SELECT
            c.AccountCategoryId,
            c.ParentId,
            c.CategoryName,
            c.ClassCode,
            c.ClassName,
            c.SortOrder,
            c.IsActive,
            t.Lvl + 1 AS Lvl,
            t.Level0,
            CAST(CASE WHEN t.Lvl = 0 THEN c.CategoryName ELSE t.Level1 END AS NVARCHAR(255)) AS Level1,
            CAST(CASE WHEN t.Lvl = 1 THEN c.CategoryName ELSE t.Level2 END AS NVARCHAR(255)) AS Level2,
            CAST(CASE WHEN t.Lvl = 2 THEN c.CategoryName ELSE t.Level3 END AS NVARCHAR(255)) AS Level3,
            t.Sort0,
            CASE WHEN t.Lvl = 0 THEN c.SortOrder ELSE t.Sort1 END AS Sort1,
            CASE WHEN t.Lvl = 1 THEN c.SortOrder ELSE t.Sort2 END AS Sort2,
            CASE WHEN t.Lvl = 2 THEN c.SortOrder ELSE t.Sort3 END AS Sort3
        FROM dbo.AccountCategory c
        INNER JOIN CatTree t
            ON c.ParentId = t.AccountCategoryId
    )

    -------------------------------------------------------------------
    -- 2) base report rows (BS classes only)
    -------------------------------------------------------------------
    SELECT
        ct.ClassCode,
        ct.ClassName,
        ct.Level0  AS CategoryLevel0,
        ct.Level1  AS CategoryLevel1,
        ct.Level2  AS CategoryLevel2,
        ct.Level3  AS CategoryLevel3,
        ct.Sort0   AS CategorySort0,
        ct.Sort1   AS CategorySort1,
        ct.Sort2   AS CategorySort2,
        ct.Sort3   AS CategorySort3,
        a.SortOrder AS AccountSortOrder,
        a.AccountId,
        a.AccountCode,
        a.AccountName,
        CAST(0 AS DECIMAL(18,2)) AS ClosingBalance
    INTO #ReportBS
    FROM dbo.Account a
    INNER JOIN CatTree ct
        ON a.AccountCategoryId = ct.AccountCategoryId
    WHERE ct.IsActive = 1
      AND a.Inactive = 0
      AND ct.ClassCode IN ('A','L','Q');

    -------------------------------------------------------------------
    -- 3) bring in balances from engine SP (AccountId-based)
    -------------------------------------------------------------------
    CREATE TABLE #CloseBal
    (
        ClosingDate             DATE,
        AccountId               INT,
        AccountCode             NVARCHAR(50),
        PriorYearEndingBalance  DECIMAL(18,2),
        CurrentPeriodBalance    DECIMAL(18,2),
        ClosingBalance          DECIMAL(18,2)
    );

    INSERT INTO #CloseBal
    EXEC dbo.Get_ClosingBalance @EndDate, NULL;

    UPDATE r
        SET r.ClosingBalance = c.ClosingBalance
    FROM #ReportBS r
    INNER JOIN #CloseBal c
        ON r.AccountId = c.AccountId;

    -------------------------------------------------------------------
    -- 4) inject net income (optional)
    --    expects an equity account with AccountCode='@NET'
    -------------------------------------------------------------------
    IF OBJECT_ID('dbo.Fn_Calc_NetIncome') IS NOT NULL
    BEGIN
        EXEC dbo.Fn_Calc_NetIncome @BeginDate, @EndDate, @NetIncome OUTPUT;

        UPDATE #ReportBS
            SET ClosingBalance = @NetIncome
        WHERE AccountCode = '@NET';
    END

    -------------------------------------------------------------------
    -- 5) final output with sort columns
    -------------------------------------------------------------------
    SELECT
        ClassCode,
        ClassName,
        CategoryLevel0,
        CategoryLevel1,
        CategoryLevel2,
        CategoryLevel3,
        CategorySort0,
        CategorySort1,
        CategorySort2,
        CategorySort3,
        AccountSortOrder,
        AccountId,
        AccountCode,
        AccountName,
        ClosingBalance
    FROM #ReportBS
    WHERE ISNULL(ClosingBalance, 0) <> 0
    ORDER BY
        ISNULL(CategorySort0, 9999),
        ISNULL(CategorySort1, 9999),
        ISNULL(CategorySort2, 9999),
        ISNULL(CategorySort3, 9999),
        ISNULL(AccountSortOrder, 9999),
        AccountCode;

    DROP TABLE #CloseBal;
    DROP TABLE #ReportBS;
END
GO
