CREATE OR ALTER TRIGGER [dbo].[TRG_Delete_Tx]
ON [dbo].[TransactionJournal]
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- This trigger handles TransactionJournal deletion in two steps:
    -- 1. Find any inventory journal detail rows that will be affected.
    -- 2. Queue those item and transaction pairs into RecalculationLog.
    -- 3. Delete the journal header row itself.
    --
    -- Why the recalculation queue is needed:
    -- deleting one journal header can change the closing quantity, average cost,
    -- and inventory value of later rows for the same item.

    DECLARE @INVAccountId INT;

    SELECT @INVAccountId = AccountId
    FROM dbo.Account
    WHERE AccountCode = '@INV';

    -- Queue recalculation only for real inventory rows.
    -- The TxId null guard is defensive protection for delete-path edge cases.
    INSERT INTO dbo.RecalculationLog (ItemId, TxId, TxDate)
    SELECT DISTINCT td.ItemId, d.TxId, d.TxDate
    FROM deleted AS d
    INNER JOIN dbo.TransactionJournalDetail AS td
        ON d.TxId = td.TxId
    WHERE d.TxId IS NOT NULL
      AND td.AccountId = @INVAccountId
      AND td.ItemId IS NOT NULL;

    -- Delete the actual journal header row after the recalculation queue is staged.
    DELETE tj
    FROM dbo.TransactionJournal AS tj
    INNER JOIN deleted AS d
        ON tj.TxId = d.TxId;
END
