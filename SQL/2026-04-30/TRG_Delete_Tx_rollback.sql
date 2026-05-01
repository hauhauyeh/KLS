CREATE OR ALTER TRIGGER [dbo].[TRG_Delete_Tx]
ON [dbo].[TransactionJournal]
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @INVAccountId INT;

    SELECT @INVAccountId = AccountId
    FROM dbo.Account
    WHERE AccountCode = '@INV';

    INSERT INTO dbo.RecalculationLog (ItemId, TxId, TxDate)
    SELECT DISTINCT td.ItemId, d.TxId, d.TxDate
    FROM deleted AS d
    INNER JOIN dbo.TransactionJournalDetail AS td
        ON d.TxId = td.TxId
    WHERE td.AccountId = @INVAccountId
      AND td.ItemId IS NOT NULL;

    DELETE tj
    FROM dbo.TransactionJournal AS tj
    INNER JOIN deleted AS d
        ON tj.TxId = d.TxId;
END
