IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.InventoryAdjDetail')
      AND name = 'IX_InventoryAdjDetail_ItemId_AdjId_History'
)
BEGIN
    DROP INDEX [IX_InventoryAdjDetail_ItemId_AdjId_History]
    ON [dbo].[InventoryAdjDetail];
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.TransactionJournalDetail')
      AND name = 'IX_TransactionJournalDetail_AccountId_ItemId_TxId_History'
)
BEGIN
    DROP INDEX [IX_TransactionJournalDetail_AccountId_ItemId_TxId_History]
    ON [dbo].[TransactionJournalDetail];
END
GO
