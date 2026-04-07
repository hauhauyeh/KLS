-- ItemImage_AddVersionFlags_rollback.sql

SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'HasNoBg1200')
    ALTER TABLE ItemImage DROP COLUMN HasNoBg1200;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'HasNoBg300')
    ALTER TABLE ItemImage DROP COLUMN HasNoBg300;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'Has2000')
    ALTER TABLE ItemImage DROP COLUMN Has2000;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'Has1200')
    ALTER TABLE ItemImage DROP COLUMN Has1200;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ItemImage') AND name = 'Has300')
    ALTER TABLE ItemImage DROP COLUMN Has300;
GO

PRINT 'ItemImage_AddVersionFlags rollback completed.';
GO
