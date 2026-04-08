-- ItemImage_DropBridgeColumns.sql
-- Drops legacy bridge columns now that SPs and HomeService use convention-based paths.
-- Run AFTER updating Item_GetAllList, ItemUnit_GetViewList, and HomeService.

SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'FileName')
    ALTER TABLE ItemImage DROP COLUMN FileName;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'RelativePath')
    ALTER TABLE ItemImage DROP COLUMN RelativePath;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'ThumbnailPath')
    ALTER TABLE ItemImage DROP COLUMN ThumbnailPath;
GO

PRINT 'Bridge columns dropped.';
GO
