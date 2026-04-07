-- ItemImage_DropBridgeColumns_rollback.sql
-- Re-adds bridge columns if needed for rollback.
-- NOTE: Data will be lost — columns come back empty.

SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'FileName')
    ALTER TABLE ItemImage ADD FileName NVARCHAR(255) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'RelativePath')
    ALTER TABLE ItemImage ADD RelativePath NVARCHAR(500) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'ThumbnailPath')
    ALTER TABLE ItemImage ADD ThumbnailPath NVARCHAR(500) NULL;
GO

PRINT 'Bridge columns re-added (empty).';
GO
