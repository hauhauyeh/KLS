-- =============================================================================
-- Web_Item_SearchInventory -- replace the hardcoded ItemType filter with
--   WEB_ITEM_TYPE_SCOPE, matching Web_Item_List.
-- 2026-09-07 (plan-web-noninventory-catalog-v2, Slice 1): this SP feeds public portal
--   search. It carried the same hardcoded ItemType = 'Inventory' as the list SP, so a
--   NonInventory tenant got an empty catalog here too. Same scope contract: Inventory
--   (default) | NonInventory | All; unknown/blank/missing falls through to 'Inventory'.
--   This SP is static SQL, so the scope is a predicate on the local scalar rather than
--   an appended string.
-- DEPLOY ORDER: deploy WITH 01-Web_Item_List-ItemTypeScope.sql -- list and search must
--   agree on scope or the portal contradicts itself.
-- Baseline: KLS/SQL/2026-09-07/Web_Item_SearchInventory_live_baseline.sql
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- EXEC dbo.Web_Item_SearchInventory @SearchTerm = 'chick'
CREATE OR ALTER PROCEDURE [dbo].[Web_Item_SearchInventory]
    @SearchTerm NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    -- 2026-09-07: per-tenant catalog scope, read exactly as in Web_Item_List. A missing
    -- row leaves it NULL and a blank value leaves it '', both collapsing to 'Inventory'.
    DECLARE @ItemTypeScope NVARCHAR(20)

    SELECT @ItemTypeScope = LTRIM(RTRIM(SettingValue))
    FROM SystemSetting WHERE SettingKey = 'WEB_ITEM_TYPE_SCOPE'

    SET @ItemTypeScope = ISNULL(NULLIF(@ItemTypeScope, ''), 'Inventory')

    ;WITH HiddenCategoryTree AS
    (
        SELECT CategoryId
        FROM dbo.ItemCategory
        WHERE LTRIM(RTRIM(ISNULL(CategoryName, ''))) = 'Raw Material'

        UNION ALL

        SELECT c.CategoryId
        FROM dbo.ItemCategory AS c
        INNER JOIN HiddenCategoryTree AS h
            ON c.ParentId = h.CategoryId
    ),
    BaseItems AS
    (
        SELECT
            i.ItemId,
            i.ItemCode,
            i.ItemName,
            ISNULL(i.LCloseQty, 0) AS LCloseQty,
            i.Inactive,
            iu.Unit AS BaseUnit,
            i.ItemSearchTag,
            CASE
                WHEN im.Has900 = 1
                THEN CONCAT('/Images/items/', im.ItemId, '/', im.ImageIndex, '-900.png')
                WHEN im.Has300 = 1
                THEN CONCAT('/Images/items/', im.ItemId, '/', im.ImageIndex, '-300.png')
                ELSE NULL
            END AS ThumbnailPath
        FROM Item AS i
        LEFT JOIN ItemUnit AS iu
            ON i.ItemId = iu.ItemId
           AND iu.IsBaseUnit = 1
        LEFT JOIN ItemImage AS im
            ON i.ItemId = im.ItemId
           AND im.IsPrimary = 1
        -- 2026-09-07: ItemType is no longer hardcoded.
        -- WHERE i.ItemType = 'Inventory'
        WHERE (
                (@ItemTypeScope = 'All')
             OR (@ItemTypeScope = 'NonInventory' AND i.ItemType = 'NonInventory')
             OR (@ItemTypeScope NOT IN ('All','NonInventory') AND i.ItemType = 'Inventory')
              )
          AND i.Inactive = 0
          AND i.IsDeleted = 0
          AND (
                i.CategoryId IS NULL
                OR NOT EXISTS
                (
                    SELECT 1
                    FROM HiddenCategoryTree AS h
                    WHERE h.CategoryId = i.CategoryId
                )
          )
    ),
    CodeMatches AS
    (
        SELECT TOP (1)
            b.ItemId,
            b.ItemCode,
            b.ItemName,
            b.LCloseQty,
            b.Inactive,
            b.BaseUnit,
            b.ThumbnailPath,
            0 AS BucketRank,
            r.SearchRank,
            r.SearchLoc
        FROM BaseItems AS b
        CROSS APPLY
        (
            SELECT
                CASE
                    WHEN b.ItemCode = @SearchTerm THEN 1
                    WHEN b.ItemCode LIKE @SearchTerm + '%' THEN 2
                    WHEN b.ItemCode LIKE '%' + @SearchTerm + '%' THEN 3
                    ELSE 99
                END AS SearchRank,
                CASE
                    WHEN b.ItemCode = @SearchTerm THEN 0
                    WHEN b.ItemCode LIKE @SearchTerm + '%' THEN 0
                    WHEN b.ItemCode LIKE '%' + @SearchTerm + '%' THEN CHARINDEX(@SearchTerm, b.ItemCode)
                    ELSE 0
                END AS SearchLoc
        ) AS r
        WHERE r.SearchRank < 99
        ORDER BY
            r.SearchRank,
            r.SearchLoc,
            LEN(b.ItemCode),
            b.ItemCode
    ),
    RemainingMatches AS
    (
        SELECT
            b.ItemId,
            b.ItemCode,
            b.ItemName,
            b.LCloseQty,
            b.Inactive,
            b.BaseUnit,
            b.ThumbnailPath,
            1 AS BucketRank,
            1 AS SearchRank,
            CHARINDEX(@SearchTerm, b.ItemCode + ' ' + b.ItemName + ' ' + ISNULL(b.ItemSearchTag, '')) AS SearchLoc
        FROM BaseItems AS b
        WHERE NOT EXISTS (SELECT 1 FROM CodeMatches AS cm WHERE cm.ItemId = b.ItemId)
          AND CHARINDEX(@SearchTerm, b.ItemCode + ' ' + b.ItemName + ' ' + ISNULL(b.ItemSearchTag, '')) > 0
    ),
    RankedResults AS
    (
        SELECT * FROM CodeMatches
        UNION ALL
        SELECT * FROM RemainingMatches
    )
    SELECT TOP (100)
        ItemId,
        ItemCode,
        ItemName,
        BaseUnit,
        LCloseQty,
        Inactive,
        NULL AS ItemSearchTag,
        CAST(NULL AS DATETIME) AS LastOrderDate,
        CAST(NULL AS DECIMAL(18,4)) AS LastOrderQty,
        CAST(NULL AS NVARCHAR(50)) AS LastOrderUnit,
        ThumbnailPath AS PrimaryImageUrl
    FROM RankedResults
    ORDER BY
        BucketRank,
        SearchRank,
        SearchLoc,
        CASE WHEN BucketRank = 0 THEN LEN(ItemCode) ELSE 0 END,
        CASE WHEN BucketRank = 0 THEN ItemCode ELSE ItemName END,
        CASE WHEN BucketRank = 0 THEN ItemName ELSE ItemCode END
    OPTION (MAXRECURSION 100);
END