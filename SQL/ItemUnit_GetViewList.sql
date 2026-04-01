-- ItemUnit_GetViewList: Returns one row per item-unit pair for the Unit View grid.
-- Accepts comma-separated ItemIds from the already-filtered/sorted product list.
-- Preserves the caller's item order via STRING_SPLIT ordinal.
-- No item-level filtering (caller already filtered). Includes inactive units (shown dimmed in UI).
-- PricePercentToBase defaults from SystemSetting 'ITEM_DEFAULT_RETAILPROFIT' if NULL or 0.

CREATE PROCEDURE [dbo].[ItemUnit_GetViewList]
    @ItemIds NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @ItemIds IS NULL OR @ItemIds = ''
    BEGIN
        SELECT TOP 0
            0 AS ItemId, '' AS ItemCode, '' AS ItemName, '' AS ImagePath,
            0 AS ItemUnitId, '' AS Unit, CAST(0 AS BIT) AS IsBaseUnit,
            CAST(0 AS BIT) AS IsDefaultSalesUnit, CAST(0 AS DECIMAL(18,6)) AS FactorToBase,
            CAST(0 AS DECIMAL(18,2)) AS RecentCost, CAST(0 AS DECIMAL(18,2)) AS P1,
            '' AS Barcode, CAST(0 AS BIT) AS Inactive,
            CAST(0 AS DECIMAL(18,4)) AS PricePercentToBase;
        RETURN;
    END

    DECLARE @DefaultPercent DECIMAL(18,4);
    SELECT @DefaultPercent = CAST(SettingValue AS DECIMAL(18,4))
    FROM SystemSetting WHERE SettingKey = 'ITEM_DEFAULT_RETAILPROFIT';

    SELECT
        i.ItemId,
        i.ItemCode,
        i.ItemName,
        img.ThumbnailPath AS ImagePath,
        iu.ItemUnitId,
        iu.Unit,
        iu.IsBaseUnit,
        iu.IsDefaultSalesUnit,
        iu.FactorToBase,
        iu.RecentCost,
        iu.P1,
        iu.Barcode,
        iu.Inactive,
        ISNULL(NULLIF(iu.PricePercentToBase, 0), @DefaultPercent) AS PricePercentToBase
    FROM STRING_SPLIT(@ItemIds, ',', 1) ss
    INNER JOIN Item i ON i.ItemId = CAST(ss.value AS INT)
    INNER JOIN ItemUnit iu ON iu.ItemId = i.ItemId
    OUTER APPLY (
        SELECT TOP 1 ThumbnailPath
        FROM ItemImage
        WHERE ItemId = i.ItemId AND IsPrimary = 1
    ) img
    ORDER BY
        ss.ordinal,
        CASE WHEN iu.IsBaseUnit = 1 THEN 0 ELSE 1 END,
        iu.Inactive,
        iu.ItemUnitId
END
GO

-- Performance index for unit view sorting
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ItemUnit_ItemId_Base' AND object_id = OBJECT_ID('ItemUnit'))
BEGIN
    CREATE INDEX IX_ItemUnit_ItemId_Base ON ItemUnit (ItemId, IsBaseUnit, ItemUnitId);
END
GO
