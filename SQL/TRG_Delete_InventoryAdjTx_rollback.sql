CREATE OR ALTER TRIGGER [dbo].[TRG_Delete_InventoryAdjTx]
   ON [dbo].[InventoryAdj]
   AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DELETE tj
    FROM dbo.TransactionJournal AS tj
    INNER JOIN deleted AS d
        ON tj.SourceDocNumber = d.AdjNumber
    WHERE tj.SourceDocType IN ('Inventory Adj', 'Inventory Adj Opening');
END
