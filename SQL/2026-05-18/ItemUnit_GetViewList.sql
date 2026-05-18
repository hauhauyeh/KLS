-- ============================================================================
-- ItemUnit_GetViewList — match alt-unit order to item-add-edit modal table
-- Round: 2026-05-18
--
-- Change: drop "iu.Inactive" from the ORDER BY. Today the SP segregates
-- active alts before inactive alts. The modal's inline unit table shows
-- alts in pure creation order with inactive rows interleaved (dimmed via
-- CSS, not reordered). The product list Unit view should match.
--
-- After:
--   base unit first
--   then alts ordered purely by ItemUnitId (creation order)
--
-- First-time modification: rename live SP to _prev (rollback baseline), then
-- DROP + CREATE the new version.
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'ItemUnit_GetViewList')
   AND NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'ItemUnit_GetViewList_prev')
    EXEC sp_rename 'ItemUnit_GetViewList', 'ItemUnit_GetViewList_prev';
GO

DROP PROCEDURE IF EXISTS dbo.ItemUnit_GetViewList;
GO

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
            0 AS ItemId,
            '' AS ItemCode,
            '' AS ItemName,
            '' AS ImagePath,
            0 AS ItemUnitId,
            '' AS Unit,
            CAST(0 AS BIT) AS IsBaseUnit,
            CAST(0 AS BIT) AS IsDefaultSalesUnit,
            CAST(0 AS DECIMAL(18,6)) AS FactorToBase,
            CAST(0 AS DECIMAL(18,2)) AS RecentCost,
            CAST(0 AS DECIMAL(18,2)) AS P1,
            '' AS Barcode,
            CAST(0 AS BIT) AS Inactive,
            CAST(0 AS DECIMAL(18,4)) AS PricePercentToBase;

        RETURN;
    END;

    DECLARE @DefaultPercent DECIMAL(18,4);

    SELECT
        @DefaultPercent = CAST(SettingValue AS DECIMAL(18,4))
    FROM SystemSetting
    WHERE SettingKey = 'ITEM_DEFAULT_RETAILPROFIT';

    SELECT
        i.ItemId,
        i.ItemCode,
        i.ItemName,
        CASE
            WHEN img.ImageId IS NOT NULL AND img.Has300 = 1
                THEN '/Images/items/' + CAST(i.ItemId AS VARCHAR(10)) + '/' + CAST(img.ImageIndex AS VARCHAR(10)) + '-300.png'
            ELSE NULL
        END AS ImagePath,
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
    INNER JOIN Item i
        ON i.ItemId = CAST(ss.value AS INT)
    INNER JOIN ItemUnit iu
        ON iu.ItemId = i.ItemId
    OUTER APPLY
    (
        SELECT TOP 1
            ImageId,
            ImageIndex,
            Has300
        FROM ItemImage
        WHERE ItemId = i.ItemId
          AND IsPrimary = 1
    ) img
    -- 2026-05-18: dropped "iu.Inactive" from ORDER BY so alt units come out
    -- in pure creation order, matching the item-add-edit modal's table. The
    -- UI already dims inactive rows via CSS; no need to segregate them here.
    -- Previous order: ss.ordinal, base-first, iu.Inactive, iu.ItemUnitId
    ORDER BY
        ss.ordinal,
        CASE
            WHEN iu.IsBaseUnit = 1 THEN 0
            ELSE 1
        END,
        iu.ItemUnitId;
END
GO
