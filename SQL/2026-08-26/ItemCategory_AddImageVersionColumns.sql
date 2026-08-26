SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Phase 2 category image metadata.
-- Adds one-image-only version flags to dbo.ItemCategory while preserving legacy ImageUrl.

IF COL_LENGTH('dbo.ItemCategory', 'OriginalImageExtension') IS NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        ADD OriginalImageExtension nvarchar(20) NULL;
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'IsImageProcessed') IS NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        ADD IsImageProcessed bit NOT NULL
            CONSTRAINT DF_ItemCategory_IsImageProcessed DEFAULT (0);
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'IsImageProcessing') IS NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        ADD IsImageProcessing bit NOT NULL
            CONSTRAINT DF_ItemCategory_IsImageProcessing DEFAULT (0);
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'HasImage300') IS NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        ADD HasImage300 bit NOT NULL
            CONSTRAINT DF_ItemCategory_HasImage300 DEFAULT (0);
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'HasImage1200') IS NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        ADD HasImage1200 bit NOT NULL
            CONSTRAINT DF_ItemCategory_HasImage1200 DEFAULT (0);
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'HasNoBg300') IS NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        ADD HasNoBg300 bit NOT NULL
            CONSTRAINT DF_ItemCategory_HasNoBg300 DEFAULT (0);
END
GO

IF COL_LENGTH('dbo.ItemCategory', 'HasNoBg1200') IS NULL
BEGIN
    ALTER TABLE dbo.ItemCategory
        ADD HasNoBg1200 bit NOT NULL
            CONSTRAINT DF_ItemCategory_HasNoBg1200 DEFAULT (0);
END
GO

