/*
    ItemImage_AddMarketplaceVersionFlags.sql
    2026-09-05: Add item image source/crop metadata and marketplace version flags.

    This script is intentionally idempotent and does not remove or alter legacy
    1200/2000 columns or files.
*/
SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF COL_LENGTH(N'dbo.ItemImage', N'OriginalWidth') IS NULL
BEGIN
    ALTER TABLE dbo.ItemImage ADD OriginalWidth int NULL;
END;

IF COL_LENGTH(N'dbo.ItemImage', N'OriginalHeight') IS NULL
BEGIN
    ALTER TABLE dbo.ItemImage ADD OriginalHeight int NULL;
END;

IF COL_LENGTH(N'dbo.ItemImage', N'EffectiveSourceWidth') IS NULL
BEGIN
    ALTER TABLE dbo.ItemImage ADD EffectiveSourceWidth int NULL;
END;

IF COL_LENGTH(N'dbo.ItemImage', N'EffectiveSourceHeight') IS NULL
BEGIN
    ALTER TABLE dbo.ItemImage ADD EffectiveSourceHeight int NULL;
END;

IF COL_LENGTH(N'dbo.ItemImage', N'CropXRatio') IS NULL
BEGIN
    ALTER TABLE dbo.ItemImage ADD CropXRatio decimal(9,6) NULL;
END;

IF COL_LENGTH(N'dbo.ItemImage', N'CropYRatio') IS NULL
BEGIN
    ALTER TABLE dbo.ItemImage ADD CropYRatio decimal(9,6) NULL;
END;

IF COL_LENGTH(N'dbo.ItemImage', N'CropSizeRatio') IS NULL
BEGIN
    ALTER TABLE dbo.ItemImage ADD CropSizeRatio decimal(9,6) NULL;
END;

IF COL_LENGTH(N'dbo.ItemImage', N'Has900') IS NULL
BEGIN
    ALTER TABLE dbo.ItemImage
        ADD Has900 bit NOT NULL CONSTRAINT DF_ItemImage_Has900 DEFAULT ((0));
END;

IF COL_LENGTH(N'dbo.ItemImage', N'Has1600') IS NULL
BEGIN
    ALTER TABLE dbo.ItemImage
        ADD Has1600 bit NOT NULL CONSTRAINT DF_ItemImage_Has1600 DEFAULT ((0));
END;

IF COL_LENGTH(N'dbo.ItemImage', N'Has2200') IS NULL
BEGIN
    ALTER TABLE dbo.ItemImage
        ADD Has2200 bit NOT NULL CONSTRAINT DF_ItemImage_Has2200 DEFAULT ((0));
END;

IF COL_LENGTH(N'dbo.ItemImage', N'HasNoBg900') IS NULL
BEGIN
    ALTER TABLE dbo.ItemImage
        ADD HasNoBg900 bit NOT NULL CONSTRAINT DF_ItemImage_HasNoBg900 DEFAULT ((0));
END;

DECLARE @SettingKey nvarchar(200) = N'ITEM_IMAGE_ROOT';
DECLARE @SettingValue nvarchar(max) = N'~/Images/items';
DECLARE @Description nvarchar(255) = N'Portable item image root. ~/ resolves under the API wwwroot.';

IF EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = @SettingKey)
BEGIN
    UPDATE dbo.SystemSetting
    SET SettingValue = @SettingValue,
        DataType = COALESCE(NULLIF(LTRIM(RTRIM(DataType)), N''), N'string'),
        Description = COALESCE(NULLIF(LTRIM(RTRIM(Description)), N''), @Description),
        UpdatedAt = GETUTCDATE()
    WHERE SettingKey = @SettingKey
      AND NULLIF(LTRIM(RTRIM(COALESCE(SettingValue, N''))), N'') IS NULL;
END
ELSE
BEGIN
    INSERT INTO dbo.SystemSetting
    (
        SettingKey,
        SettingValue,
        DataType,
        Description,
        CreatedAt
    )
    VALUES
    (
        @SettingKey,
        @SettingValue,
        N'string',
        @Description,
        GETUTCDATE()
    );
END;

COMMIT TRANSACTION;

PRINT 'ItemImage marketplace version flags schema script completed.';
