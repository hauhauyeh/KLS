-- ItemImage_AddVersionFlags.sql
-- Adds per-version existence flags to ItemImage table.
-- These track exactly which derivative files exist on disk.

SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'Has300')
    ALTER TABLE ItemImage ADD Has300 BIT NOT NULL DEFAULT 0;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'Has1200')
    ALTER TABLE ItemImage ADD Has1200 BIT NOT NULL DEFAULT 0;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'Has2000')
    ALTER TABLE ItemImage ADD Has2000 BIT NOT NULL DEFAULT 0;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'HasNoBg300')
    ALTER TABLE ItemImage ADD HasNoBg300 BIT NOT NULL DEFAULT 0;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'HasNoBg1200')
    ALTER TABLE ItemImage ADD HasNoBg1200 BIT NOT NULL DEFAULT 0;
GO

PRINT 'ItemImage_AddVersionFlags completed.';
GO
