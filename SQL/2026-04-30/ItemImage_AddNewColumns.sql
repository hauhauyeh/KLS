-- ItemImage_AddNewColumns.sql
-- Adds ImageIndex, OriginalExtension, IsProcessed, IsProcessing to ItemImage table
-- Old columns (FileName, RelativePath, ThumbnailPath) kept for now — dropped after service migration

SET QUOTED_IDENTIFIER ON;
GO

-- Add ImageIndex (1-based, immutable file naming index)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'ImageIndex')
BEGIN
    ALTER TABLE ItemImage ADD ImageIndex INT NOT NULL DEFAULT 1;
END
GO

-- Add OriginalExtension (preserves uploaded file extension, e.g. '.jpg')
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'OriginalExtension')
BEGIN
    ALTER TABLE ItemImage ADD OriginalExtension NVARCHAR(10) NULL;
END
GO

-- Add IsProcessed (BG removal done, no-bg files exist)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'IsProcessed')
BEGIN
    ALTER TABLE ItemImage ADD IsProcessed BIT NOT NULL DEFAULT 0;
END
GO

-- Add IsProcessing (lock flag to prevent concurrent processing)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'IsProcessing')
BEGIN
    ALTER TABLE ItemImage ADD IsProcessing BIT NOT NULL DEFAULT 0;
END
GO

-- Populate ImageIndex from SortOrder for existing rows
UPDATE ItemImage SET ImageIndex = SortOrder WHERE ImageIndex = 1 AND SortOrder > 1;
GO

-- Unique constraint: prevent duplicate ImageIndex per item (filename collision protection)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_ItemImage_ItemId_ImageIndex' AND object_id = OBJECT_ID('ItemImage'))
BEGIN
    CREATE UNIQUE INDEX UQ_ItemImage_ItemId_ImageIndex ON ItemImage (ItemId, ImageIndex);
END
GO

PRINT 'ItemImage_AddNewColumns completed successfully.';
GO
