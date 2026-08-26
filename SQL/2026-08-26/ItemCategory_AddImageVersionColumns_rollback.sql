SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Rollback for ItemCategory_AddImageVersionColumns.sql.
-- Drops only the Phase 2 category image metadata columns; preserves legacy ImageUrl.

IF OBJECT_ID('dbo.DF_ItemCategory_IsImageProcessed', 'D') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP CONSTRAINT DF_ItemCategory_IsImageProcessed;
END
GO

IF OBJECT_ID('dbo.DF_ItemCategory_IsImageProcessing', 'D') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP CONSTRAINT DF_ItemCategory_IsImageProcessing;
END
GO

IF OBJECT_ID('dbo.DF_ItemCategory_HasImage300', 'D') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP CONSTRAINT DF_ItemCategory_HasImage300;
END
GO

IF OBJECT_ID('dbo.DF_ItemCategory_HasImage1200', 'D') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP CONSTRAINT DF_ItemCategory_HasImage1200;
END
GO

IF OBJECT_ID('dbo.DF_ItemCategory_HasNoBg300', 'D') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP CONSTRAINT DF_ItemCategory_HasNoBg300;
END
GO

IF OBJECT_ID('dbo.DF_ItemCategory_HasNoBg1200', 'D') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP CONSTRAINT DF_ItemCategory_HasNoBg1200;
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'HasNoBg1200') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP COLUMN HasNoBg1200;
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'HasNoBg300') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP COLUMN HasNoBg300;
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'HasImage1200') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP COLUMN HasImage1200;
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'HasImage300') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP COLUMN HasImage300;
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'IsImageProcessing') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP COLUMN IsImageProcessing;
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'IsImageProcessed') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP COLUMN IsImageProcessed;
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'OriginalImageExtension') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        DROP COLUMN OriginalImageExtension;
END
GO

