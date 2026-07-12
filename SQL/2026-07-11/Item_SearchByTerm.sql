SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[Item_SearchByTerm]
    @SearchTerm NVARCHAR(100),
    @ShowInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH cte AS
    (
        SELECT
            i.ItemId,
            i.ItemCode,
            i.ItemName,
            ISNULL(i.LCloseQty, 0) AS LCloseQty,
            i.Inactive,
            -- Old: CHARINDEX(@SearchTerm, i.ItemCode + ' ' + i.ItemName + ' ' + ISNULL(i.ItemSearchTag, '')) AS DescLoc,
            -- 2026-07-11: normal rows are name/tag search only; the best ItemCode
            -- match gets its own reserved top slot below.
            CHARINDEX(
                @SearchTerm,
                i.ItemName + ' ' + ISNULL(i.ItemSearchTag, '')
            ) AS DescLoc,
            iu.Unit AS BaseUnit,
            CASE 
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
        WHERE (@ShowInactive = 1 OR i.Inactive = 0)
          AND i.IsDeleted = 0
    ),
    -- Old:
    -- ctefinal AS
    -- (
    --     SELECT *, 1 AS rn FROM cte WHERE ItemCode = @SearchTerm
    --     UNION
    --     SELECT *, 2 AS rn FROM cte WHERE barcode matched @SearchTerm
    --     UNION
    --     SELECT *, 3 AS rn FROM cte WHERE DescLoc > 0
    -- )
    -- 2026-07-11: reserve only one top slot for the best ItemCode match
    -- (exact, prefix, contains), then return normal name/tag search rows.
    PinnedCode AS
    (
        SELECT TOP (1) *, 1 AS rn
        FROM cte
        WHERE ItemCode LIKE '%' + @SearchTerm + '%'
        ORDER BY
            CASE
                WHEN ItemCode = @SearchTerm THEN 0
                WHEN ItemCode LIKE @SearchTerm + '%' THEN 1
                ELSE 2
            END,
            LEN(ItemCode),
            ItemCode,
            ItemName
    ),
    ctefinal AS
    (
        SELECT * FROM PinnedCode

        UNION ALL

        SELECT cte.*, 2 AS rn
        FROM cte
        WHERE DescLoc > 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM PinnedCode pc
              WHERE pc.ItemId = cte.ItemId
          )
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
    FROM ctefinal
    ORDER BY rn, DescLoc, ItemName;
END
