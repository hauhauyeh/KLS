/*
    ItemImage_AddMarketplaceVersionFlags_rollback.sql
    2026-09-05: Conservative rollback for ItemImage_AddMarketplaceVersionFlags.sql.

    Drops only columns added by the paired script. ITEM_IMAGE_ROOT is removed
    only when it still exactly matches the paired script default and description.
*/
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DECLARE @TableName sysname = N'ItemImage';
DECLARE @SchemaName sysname = N'dbo';
DECLARE @ObjectName nvarchar(257) = @SchemaName + N'.' + @TableName;
DECLARE @FullTableName nvarchar(257) = QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName);
DECLARE @Sql nvarchar(max);

DECLARE @Columns TABLE
(
    ColumnName sysname NOT NULL PRIMARY KEY
);

INSERT INTO @Columns (ColumnName)
VALUES
    (N'OriginalWidth'),
    (N'OriginalHeight'),
    (N'EffectiveSourceWidth'),
    (N'EffectiveSourceHeight'),
    (N'CropXRatio'),
    (N'CropYRatio'),
    (N'CropSizeRatio'),
    (N'Has900'),
    (N'Has1600'),
    (N'Has2200'),
    (N'HasNoBg900');

DECLARE @ColumnName sysname;
DECLARE @DefaultConstraintName sysname;

DECLARE ColumnCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT ColumnName
    FROM @Columns;

OPEN ColumnCursor;
FETCH NEXT FROM ColumnCursor INTO @ColumnName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @DefaultConstraintName = dc.name
    FROM sys.default_constraints dc
    INNER JOIN sys.columns c
        ON c.default_object_id = dc.object_id
    INNER JOIN sys.tables t
        ON t.object_id = c.object_id
    INNER JOIN sys.schemas s
        ON s.schema_id = t.schema_id
    WHERE s.name = @SchemaName
      AND t.name = @TableName
      AND c.name = @ColumnName;

    IF @DefaultConstraintName IS NOT NULL
    BEGIN
        SET @Sql = N'ALTER TABLE ' + @FullTableName
            + N' DROP CONSTRAINT ' + QUOTENAME(@DefaultConstraintName) + N';';
        EXEC sp_executesql @Sql;
    END;

    IF COL_LENGTH(@ObjectName, @ColumnName) IS NOT NULL
    BEGIN
        SET @Sql = N'ALTER TABLE ' + @FullTableName
            + N' DROP COLUMN ' + QUOTENAME(@ColumnName) + N';';
        EXEC sp_executesql @Sql;
    END;

    SET @DefaultConstraintName = NULL;
    FETCH NEXT FROM ColumnCursor INTO @ColumnName;
END;

CLOSE ColumnCursor;
DEALLOCATE ColumnCursor;

DELETE FROM dbo.SystemSetting
WHERE SettingKey = N'ITEM_IMAGE_ROOT'
  AND SettingValue = N'~/Images/items'
  AND Description = N'Portable item image root. ~/ resolves under the API wwwroot.';

COMMIT TRANSACTION;

PRINT 'ItemImage marketplace version flags rollback completed.';
