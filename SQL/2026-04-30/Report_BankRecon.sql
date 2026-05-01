-- Deploy: Create Report_BankRecon SP
-- New report: Bank Reconciliation detail for a specific recon period

CREATE PROCEDURE [dbo].[Report_BankRecon]
    @BankReconId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccountId INT, @StatementDate DATE, @StatementBalance DECIMAL(18,2), @BeginningBalance DECIMAL(18,2);

    SELECT @AccountId = AccountId,
           @StatementDate = StatementDate,
           @StatementBalance = StatementBalance,
           @BeginningBalance = BeginningBalance
    FROM BankRecon
    WHERE BankReconId = @BankReconId;

    SELECT
        CAST(ROW_NUMBER() OVER (ORDER BY t.TxDate, t.TxId) AS INT) AS RowId,
        t.TxId,
        t.TxDate,
        t.SourceDocType,
        t.SourceDocNumber,
        p.PayeeName,
        td.Amount,
        t.BankDate,
        CASE WHEN t.BankDate IS NOT NULL AND t.BankDate <= @StatementDate THEN 1 ELSE 0 END AS IsCleared,
        ac.AccountName,
        @StatementDate AS StatementDate,
        @StatementBalance AS StatementBalance,
        @BeginningBalance AS BeginningBalance
    FROM TransactionJournal t
    INNER JOIN TransactionJournalDetail td ON t.TxId = td.TxId
    INNER JOIN Account ac ON ac.AccountId = td.AccountId
    LEFT JOIN Payee p ON td.PayeeId = p.PayeeId
    WHERE td.AccountId = @AccountId
      AND t.TxDate <= @StatementDate
      AND (t.BankDate IS NULL OR t.BankDate <= @StatementDate)
    ORDER BY t.TxDate, t.TxId;
END
