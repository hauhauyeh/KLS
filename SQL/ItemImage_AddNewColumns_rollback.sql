-- ItemImage_AddNewColumns_rollback.sql
-- Reverses ItemImage_AddNewColumns.sql

SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ItemImage_ItemId_ImageIndex' AND object_id = OBJECT_ID('ItemImage'))
BEGIN
    DROP INDEX UQ_ItemImage_ItemId_ImageIndex ON ItemImage;
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'IsProcessing')
BEGIN
    ALTER TABLE ItemImage DROP COLUMN IsProcessing;
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'IsProcessed')
BEGIN
    ALTER TABLE ItemImage DROP COLUMN IsProcessed;
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'OriginalExtension')
BEGIN
    ALTER TABLE ItemImage DROP COLUMN OriginalExtension;
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'ImageIndex')
BEGIN
    ALTER TABLE ItemImage DROP COLUMN ImageIndex;
END
GO

PRINT 'ItemImage_AddNewColumns rollback completed successfully.';
GO
