
CREATE PROCEDURE [dbo].[Get_ClosingBalance]
    @EndDate   DATE,
    @AcctCode  NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- sys start date default
    DECLARE @SysStartDate DATE;

    SELECT @SysStartDate = SettingValue 
    FROM SystemSetting WHERE SettingKey = 'SYSTEM_START_DATE'

    -- optional filter resolve
    DECLARE @AcctId INT = NULL;

    IF @AcctCode IS NOT NULL
    BEGIN
        SELECT @AcctId = a.AccountId
        FROM dbo.Account a
        WHERE a.AccountCode = @AcctCode;

        IF @AcctId IS NULL
        BEGIN
            -- return empty set
            SELECT
                @EndDate AS ClosingDate,
                CAST(NULL AS INT) AS AccountId,
                CAST(NULL AS NVARCHAR(50)) AS AccountCode,
                CAST(0 AS MONEY) AS PriorYearEndingBalance,
                CAST(0 AS MONEY) AS CurrentPeriodBalance,
                CAST(0 AS MONEY) AS ClosingBalance
            WHERE 1 = 0;
            RETURN;
        END
    END

    -- latest archived snapshot date <= @EndDate
    DECLARE @LastCloseDate DATE;

    SELECT @LastCloseDate = MAX(ClosingDate)
    FROM dbo.AccountYearEndBalance
    WHERE ClosingDate <= @EndDate;

    -- live range start
    DECLARE @UnclosedStartDate DATE =
        CASE
            WHEN @LastCloseDate IS NULL THEN @SysStartDate
            ELSE DATEADD(DAY, 1, @LastCloseDate)
        END;

    ;WITH Closed AS
    (
        -- snapshot as-of last close date (if any)
        SELECT
            y.AccountId,
            SUM(y.ClosingBalance) AS PriorYearEndingBalance
        FROM dbo.AccountYearEndBalance y
        WHERE y.ClosingDate = @LastCloseDate
          AND y.AccountId IS NOT NULL
          AND y.AccountId = ISNULL(@AcctId, y.AccountId)
        GROUP BY y.AccountId
    ),
    Unclosed AS
    (
        -- current activity since last close date (or system start date)
        SELECT
            td.AccountId,
            SUM(td.Amount) AS CurrentPeriodBalance
        FROM dbo.TransactionJournal t
        INNER JOIN dbo.TransactionJournalDetail td
            ON td.TxId = t.TxId
        WHERE t.TxDate >= @UnclosedStartDate
          AND t.TxDate <  DATEADD(DAY, 1, @EndDate)
          AND td.AccountId IS NOT NULL
          AND td.AccountId = ISNULL(@AcctId, td.AccountId)
        GROUP BY td.AccountId
    ),
    Merged AS
    (
        SELECT
            COALESCE(c.AccountId, u.AccountId) AS AccountId,
            ISNULL(c.PriorYearEndingBalance, 0) AS PriorYearEndingBalance,
            ISNULL(u.CurrentPeriodBalance, 0) AS CurrentPeriodBalance
        FROM Closed c
        FULL OUTER JOIN Unclosed u
            ON u.AccountId = c.AccountId
    )
    SELECT
        @EndDate AS ClosingDate,
        a.AccountId,
        a.AccountCode,
        m.PriorYearEndingBalance,
        m.CurrentPeriodBalance,
        m.PriorYearEndingBalance + m.CurrentPeriodBalance AS ClosingBalance
    FROM Merged m
    INNER JOIN dbo.Account a
        ON a.AccountId = m.AccountId
    WHERE m.PriorYearEndingBalance <> 0
       OR m.CurrentPeriodBalance <> 0
    ORDER BY a.AccountCode;
END

