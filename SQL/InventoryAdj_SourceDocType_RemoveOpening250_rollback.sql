-- Restore the retired Inventory Adj Opening mapping if rollback is needed.

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SourceDocType
    WHERE DocType = 'Inventory Adj Opening'
)
BEGIN
    INSERT INTO dbo.SourceDocType (DocType, DocOrder)
    VALUES ('Inventory Adj Opening', 250);
END
