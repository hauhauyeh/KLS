-- Deploy: Create Report_LedgerEmpLoan SP
-- Migrated from KLS_New to KLS_Latest (column names updated)

CREATE PROCEDURE [dbo].[Report_LedgerEmpLoan]
    @StartDate DATE,
    @EndDate DATE,
    @PayeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccountId INT = (SELECT AccountId FROM Account WHERE AccountCode = '@ARE');

    DECLARE @Tx AS TABLE
    (
        AutoId INT IDENTITY(1,1),
        PayeeId INT,
        PayeeName NVARCHAR(255),
        TxNum INT,
        TxDate DATE,
        SourceDocType NVARCHAR(100),
        SourceDocNum INT,
        Amount MONEY,
        DebitAmt MONEY,
        CreditAmt MONEY,
        AcctBalance MONEY,
        OpeningBalance MONEY
    )

    INSERT INTO @Tx(PayeeId, TxNum, TxDate, SourceDocType, SourceDocNum, Amount, DebitAmt, CreditAmt, AcctBalance)
    SELECT td.PayeeId, t.TxId, t.TxDate, t.SourceDocType, t.SourceDocNumber, td.Amount,
        CASE WHEN td.CrDeAmount < 0 THEN ABS(td.CrDeAmount) ELSE 0 END AS DebitAmt,
        CASE WHEN td.CrDeAmount > 0 THEN td.CrDeAmount ELSE 0 END AS CreditAmt,
        SUM(td.Amount) OVER(PARTITION BY td.PayeeId ORDER BY t.TxDate, t.SourceDocOrder, td.TxDetailId) AS AcctBalance
    FROM TransactionJournal AS t
    INNER JOIN TransactionJournalDetail AS td ON t.TxId = td.TxId
    WHERE td.AccountId = @AccountId
      AND td.PayeeId = ISNULL(@PayeeId, td.PayeeId)

    UPDATE t SET t.PayeeName = p.PayeeName
    FROM @Tx AS t INNER JOIN Payee AS p ON t.PayeeId = p.PayeeId

    SELECT * FROM @Tx WHERE TxDate BETWEEN @StartDate AND @EndDate
END
