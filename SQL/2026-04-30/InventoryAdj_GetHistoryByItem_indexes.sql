-- Supporting indexes for dbo.InventoryAdj_GetHistoryByItem.
-- These are intentionally narrow to support the Product List Qty Adj modal history lookup.

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.TransactionJournalDetail')
      AND name = 'IX_TransactionJournalDetail_AccountId_ItemId_TxId_History'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_TransactionJournalDetail_AccountId_ItemId_TxId_History]
    ON [dbo].[TransactionJournalDetail] ([AccountId], [ItemId], [TxId])
    INCLUDE ([TxDetailId], [ClosingQty], [AverageCost]);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.InventoryAdjDetail')
      AND name = 'IX_InventoryAdjDetail_ItemId_AdjId_History'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_InventoryAdjDetail_ItemId_AdjId_History]
    ON [dbo].[InventoryAdjDetail] ([ItemId], [AdjId])
    INCLUDE ([AdjDetailId], [NewQty], [NewPrice], [Notes]);
END
GO
