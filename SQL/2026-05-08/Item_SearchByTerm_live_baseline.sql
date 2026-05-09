-- Live baseline of dbo.Item_SearchByTerm captured 2026-05-08.
-- Frozen rollback reference for the I-only forward-removal round.
-- See future-product-list-remove-d.md, Step 1.2.


CREATE PROCEDURE [dbo].[Item_SearchByTerm]
    @SearchTerm NVARCHAR(100),
    -- Old @IsActiveOnly BIT replaced by two ambient bits below.
    -- @ShowInactive: when 1, results include rows where Inactive = 1.
    --                Default 0 keeps the dropdown active-only as before.
    -- @ShowDeleted:  when 1, results include rows where IsDeleted = 1.
    --                Default 0 hides deleted rows -- preserves prior
    --                behaviour for any caller that wasn't passing the
    --                old @IsActiveOnly = 0 "show everything" sentinel.
    @ShowInactive BIT = 0,
    @ShowDeleted  BIT = 0
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
            i.IsDeleted,                          -- NEW 2026-05-07: lets dropdown dim deleted rows
            CHARINDEX(@SearchTerm, i.ItemCode + ' ' + i.ItemName + ' ' + ISNULL(i.ItemSearchTag, '')) AS DescLoc,
            iu.Unit AS BaseUnit,
            CASE WHEN im.Has300 = 1 THEN CONCAT('/Images/items/', im.ItemId, '/', im.ImageIndex, '-300.png') ELSE NULL END AS ThumbnailPath
        FROM Item AS i
        LEFT JOIN ItemUnit AS iu
            ON i.ItemId = iu.ItemId
           AND iu.IsBaseUnit = 1
        LEFT JOIN ItemImage AS im ON i.ItemId = im.ItemId AND im.IsPrimary = 1
        -- ------------------------------------------------------------------
        -- Visibility scope. Truth table identical to Item_GetAllList:
        --
        --   @ShowInactive @ShowDeleted   rows returned
        --   ------------- -------------  ----------------------------------
        --        0             0         active only (Inactive=0 AND IsDeleted=0)
        --        1             0         active + inactive (IsDeleted=0)
        --        0             1         active + deleted (Inactive=0)
        --        1             1         everything (no scope filter)
        --
        -- Each filter is independent: the predicate is added only when
        -- its flag is 0 ("exclude this kind"). When both flags are 1,
        -- neither predicate is added and we get every matching item.
        --
        -- Old WHERE preserved for reference:
        --     WHERE @IsActiveOnly = 0
        --           OR (i.Inactive = 0 AND i.IsDeleted = 0)
        -- ------------------------------------------------------------------
        WHERE (@ShowInactive = 1 OR i.Inactive  = 0)
          AND (@ShowDeleted  = 1 OR i.IsDeleted = 0)
    ),
    ctefinal AS
    (
        SELECT *, 1 AS rn FROM cte WHERE ItemCode = @SearchTerm
        UNION
        SELECT *, 2 AS rn FROM cte WHERE DescLoc > 0 AND ItemCode <> @SearchTerm
    )
    SELECT TOP (100)
        ItemId, ItemCode, ItemName, BaseUnit, LCloseQty, Inactive,
        IsDeleted,                                -- NEW 2026-05-07
        NULL AS ItemSearchTag,
        CAST(NULL AS DATETIME) AS LastOrderDate,
        CAST(NULL AS DECIMAL(18,4)) AS LastOrderQty,
        CAST(NULL AS NVARCHAR(50)) AS LastOrderUnit,
        ThumbnailPath AS PrimaryImageUrl
    FROM ctefinal
    ORDER BY rn, DescLoc, ItemName;
END

