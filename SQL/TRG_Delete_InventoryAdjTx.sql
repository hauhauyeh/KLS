CREATE OR ALTER TRIGGER [dbo].[TRG_Delete_InventoryAdjTx]
   ON [dbo].[InventoryAdj]
   AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- When an inventory adjustment header is deleted, remove the matching
    -- TransactionJournal header row for the same adjustment number.
    --
    -- Supported timing types:
    -- - Inventory Adj         = Before Receiving
    -- - Inventory Adj Closing = After Receiving
    --
    -- The journal delete then flows into TRG_Delete_Tx, which queues the
    -- affected inventory rows for recalculation before removing the journal row.
    DELETE tj
    FROM dbo.TransactionJournal AS tj
    INNER JOIN deleted AS d
        ON tj.SourceDocNumber = d.AdjNumber
    WHERE tj.SourceDocType IN ('Inventory Adj', 'Inventory Adj Closing');
END
