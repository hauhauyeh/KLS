-- Deploy: Create Report_LedgerByPayee SP
-- Migrated from KLS_New with updated column/table names

CREATE PROCEDURE [dbo].[Report_LedgerByPayee]
    @StartDate DATE,
    @EndDate DATE,
    @PayeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CONVERT(int, ROW_NUMBER() OVER(ORDER BY t.TxDate, t.SourceDocOrder, td.TxDetailId)) AS AutoId,
        t.TxDate,
        t.TxId AS TxNum,
        t.SourceDocType,
        t.SourceDocNumber AS SourceDocNum,
        NULL AS PayeeName,
        td.Amount,
        ac.AccountName AS ChartAcctName,
        0.0 AS AcctBalance,
        0.0 AS OpeningBalance
    FROM TransactionJournal AS t
    INNER JOIN TransactionJournalDetail AS td ON t.TxId = td.TxId
    INNER JOIN Account AS ac ON ac.AccountId = td.AccountId
    WHERE td.PayeeId = @PayeeId
      AND t.TxDate BETWEEN @StartDate AND @EndDate
    ORDER BY t.TxDate DESC, t.SourceDocOrder, td.TxDetailId
END
