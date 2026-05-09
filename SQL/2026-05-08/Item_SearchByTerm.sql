-- Item_SearchByTerm rev 2026-05-08 (I-only forward-removal)
-- Removes the @ShowDeleted parameter and the IsDeleted projection added in
-- the 2026-05-07 round. Keeps @ShowInactive (which the autocomplete maps
-- via the back-compat translator on the frontend) and unconditionally
-- filters i.IsDeleted = 0 in the WHERE.
--
-- Also drops i.IsDeleted from the CTE projection and the final SELECT;
-- the DTO ItemSearch no longer carries IsDeleted, so projecting it would
-- throw at EF materialization (this is the same DTO that
-- Item_ListActiveForKeybox writes into, and was the root cause of the
-- keybox-cache failure -- removing the column here AND from the DTO
-- restores the schema match).
--
-- Workflow: 5-step SQL workflow per CLAUDE.md. This file is the
-- workspace-root scratch; baseline is at
-- KLS\SQL\2026-05-08\Item_SearchByTerm_live_baseline.sql.

-- _prev already exists from prior rounds; rename guard is a no-op here.
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Item_SearchByTerm')
   AND NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Item_SearchByTerm_prev')
    EXEC sp_rename 'Item_SearchByTerm', 'Item_SearchByTerm_prev';
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Item_SearchByTerm')
    DROP PROCEDURE dbo.Item_SearchByTerm;
GO

CREATE PROCEDURE [dbo].[Item_SearchByTerm]
    @SearchTerm NVARCHAR(100),
    -- Old @ShowDeleted BIT = 0 removed 2026-05-08 (forward-removal of D toggle).
    -- Deleted items are now always hidden via the unconditional
    -- AND i.IsDeleted = 0 in the WHERE clause below.
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
            -- i.IsDeleted removed 2026-05-08 -- DTO ItemSearch no longer carries it.
            CHARINDEX(@SearchTerm, i.ItemCode + ' ' + i.ItemName + ' ' + ISNULL(i.ItemSearchTag, '')) AS DescLoc,
            iu.Unit AS BaseUnit,
            CASE WHEN im.Has300 = 1 THEN CONCAT('/Images/items/', im.ItemId, '/', im.ImageIndex, '-300.png') ELSE NULL END AS ThumbnailPath
        FROM Item AS i
        LEFT JOIN ItemUnit AS iu
            ON i.ItemId = iu.ItemId
           AND iu.IsBaseUnit = 1
        LEFT JOIN ItemImage AS im ON i.ItemId = im.ItemId AND im.IsPrimary = 1
        -- ------------------------------------------------------------------
        -- Visibility scope (I-only, 2026-05-08).
        --
        -- The D toggle was removed; deleted items are now always hidden
        -- regardless of any flag. Only the I toggle remains.
        --
        --   @ShowInactive    rows returned (deleted always excluded)
        --   -------------    ------------------------------------------
        --        0           active only           (Inactive=0 AND IsDeleted=0)
        --        1           active + inactive     (IsDeleted=0)
        --
        -- Previous (2026-05-07) two-bit WHERE:
        --     WHERE (@ShowInactive = 1 OR i.Inactive  = 0)
        --       AND (@ShowDeleted  = 1 OR i.IsDeleted = 0)
        --
        -- And before that (2026-05-06 baseline) the IsActiveOnly WHERE:
        --     WHERE @IsActiveOnly = 0
        --        OR (i.Inactive = 0 AND i.IsDeleted = 0)
        -- ------------------------------------------------------------------
        WHERE (@ShowInactive = 1 OR i.Inactive = 0)
          AND i.IsDeleted = 0
    ),
    ctefinal AS
    (
        SELECT *, 1 AS rn FROM cte WHERE ItemCode = @SearchTerm
        UNION
        SELECT *, 2 AS rn FROM cte WHERE DescLoc > 0 AND ItemCode <> @SearchTerm
    )
    SELECT TOP (100)
        ItemId, ItemCode, ItemName, BaseUnit, LCloseQty, Inactive,
        -- IsDeleted removed 2026-05-08 from final SELECT
        NULL AS ItemSearchTag,
        CAST(NULL AS DATETIME) AS LastOrderDate,
        CAST(NULL AS DECIMAL(18,4)) AS LastOrderQty,
        CAST(NULL AS NVARCHAR(50)) AS LastOrderUnit,
        ThumbnailPath AS PrimaryImageUrl
    FROM ctefinal
    ORDER BY rn, DescLoc, ItemName;
END
GO
