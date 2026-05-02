CREATE PROCEDURE [dbo].[Report_Ledger]
    @StartDate  DATE,
    @EndDate    DATE,
    @AccountId  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OpeningBalance DECIMAL(18,2) = 0;

    -- Opening balance: archived snapshot + unclosed activity before @StartDate
    DECLARE @LastCloseDate DATE;
    SELECT @LastCloseDate = MAX(ClosingDate)
    FROM dbo.AccountYearEndBalance
    WHERE ClosingDate < @StartDate;

    DECLARE @ClosedBal DECIMAL(18,2) = 0;
    IF @LastCloseDate IS NOT NULL
        SELECT @ClosedBal = ISNULL(SUM(ClosingBalance), 0)
        FROM dbo.AccountYearEndBalance
        WHERE AccountId = @AccountId AND ClosingDate = @LastCloseDate;

    DECLARE @UnclosedStart DATE = ISNULL(DATEADD(DAY, 1, @LastCloseDate), '2017-01-01');

    DECLARE @UnclosedBal DECIMAL(18,2) = 0;
    SELECT @UnclosedBal = ISNULL(SUM(td.Amount), 0)
    FROM dbo.TransactionJournal t
    INNER JOIN dbo.TransactionJournalDetail td ON td.TxId = t.TxId
    WHERE td.AccountId = @AccountId
      AND t.TxDate >= @UnclosedStart
      AND t.TxDate < @StartDate;

    SET @OpeningBalance = @ClosedBal + @UnclosedBal;

    -- Transaction detail rows
    -- Debit/Credit derived from Amount sign (Amount is signed per accounting rules)
    SELECT
        t.TxId                  AS TxNum,
        t.TxDate,
        p.PayeeName             AS Payee,
        t.SourceDocType + ' #' + CAST(t.SourceDocNumber AS VARCHAR(20)) AS DocType,
        CASE WHEN td.Amount < 0 THEN td.Amount ELSE 0 END AS Debit,
        CASE WHEN td.Amount > 0 THEN td.Amount ELSE 0 END AS Credit,
        td.Amount,
        @OpeningBalance         AS OpeningBalance
    FROM dbo.TransactionJournal t
    INNER JOIN dbo.TransactionJournalDetail td ON td.TxId = t.TxId
    LEFT JOIN dbo.Payee p ON td.PayeeId = p.PayeeId
    WHERE td.AccountId = @AccountId
      AND t.TxDate >= @StartDate
      AND t.TxDate <  DATEADD(DAY, 1, @EndDate)
    ORDER BY t.TxDate, t.TxId, td.TxDetailId;
END