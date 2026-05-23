/*
    Promotion_GetAllList.sql
    2026-05-22

    Adds RecentCost, P1, AfterPromoPrice to the non-count SELECT.

    Values populate ONLY when:
      - PromotionType = 'BOGO_ITEM_CATEGORY'
      - Exactly one PromotionBogo row exists with ConditionType='ITEM'
        and ConditionItemId IS NOT NULL

    AfterPromoPrice = ROUND(PromoPrice * ConditionQty / (ConditionQty + RewardQty), 2)
    -- the effective per-unit price after BOGO math (e.g. buy 5 get 1 free at $29.99
    -- gives 5 * 29.99 / 6 = $24.99 effective per unit).

    For multi-rule / CATEGORY-scoped / cart-wide promos, the OUTER APPLY returns
    NULL on all three fields and the frontend renders em-dash.

    Count branch (@IsCount = 1) is untouched.

    Deploy script (CLAUDE.md Rule 5):
      - First modification of this proc → rename to _prev (guarded; no-op if
        _prev already exists from a prior round).
      - DROP + CREATE the working proc.
*/

-- SET options must match the live SP's compile-time options, otherwise
-- writes against tables with filtered indexes / computed columns / indexed
-- views throw Msg 1934 at runtime. See kls-sql-standard.md Part 1
-- "Required SP Header".
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- _prev rename: one-time only (CLAUDE.md feedback_sp_rename_once).
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Promotion_GetAllList')
   AND NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Promotion_GetAllList_prev')
    EXEC sp_rename 'Promotion_GetAllList', 'Promotion_GetAllList_prev';
GO

DROP PROCEDURE IF EXISTS [dbo].[Promotion_GetAllList];
GO

CREATE PROCEDURE [dbo].[Promotion_GetAllList] --[dbo].[Promotion_GetAllList] Null,Null,Null,Null,Null,Null,Null,Null,0,0
    @Pageno INT,
    @Pagesize INT,
    @Search NVARCHAR(100),
    @StartDate DATE,
    @EndDate DATE,
    @Filterby NVARCHAR(100),
    @SortField NVARCHAR(50),
    @SortOrder NVARCHAR(50),
    @IsCount BIT,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);

    IF @IsCount = 1
        SET @Qry = 'SELECT @RCount = COUNT(*)';
    ELSE
        SET @Qry = '
        SELECT P.PromotionId, P.Name, P.DisplayName, P.PromotionType,
               P.StartDate, P.EndDate, P.IsActive,
               sb.RecentCost, sb.P1, sb.PromoPrice, sb.AfterPromoPrice ';

    SET @Qry += ' FROM Promotion AS P ';

    -- Pricing resolver for single-rule BOGO_ITEM_CATEGORY promos.
    -- NULL for everything else (multi-rule, CATEGORY-scoped, cart-wide types).
    -- Only attached on the non-count branch so the COUNT(*) query stays cheap.
    -- RecentCost and P1 both live on ItemUnit (base unit row); single lookup.
    IF @IsCount = 0
        SET @Qry += '
        OUTER APPLY (
            SELECT TOP 1
                iu.RecentCost,
                iu.P1,
                pb.PromoPrice,
                CASE
                    WHEN (pb.ConditionQty + pb.RewardQty) > 0 AND pb.PromoPrice IS NOT NULL
                    THEN ROUND(pb.PromoPrice * pb.ConditionQty * 1.0 / (pb.ConditionQty + pb.RewardQty), 2)
                    ELSE NULL
                END AS AfterPromoPrice
            FROM PromotionBogo pb
            OUTER APPLY (
                SELECT TOP 1 ItemUnit.RecentCost, ItemUnit.P1 FROM ItemUnit
                WHERE ItemUnit.ItemId = pb.ConditionItemId AND ItemUnit.IsBaseUnit = 1
            ) iu
            WHERE pb.PromotionId = P.PromotionId
              AND pb.ConditionType = ''ITEM''
              AND pb.ConditionItemId IS NOT NULL
              AND P.PromotionType = ''BOGO_ITEM_CATEGORY''
              AND (
                  SELECT COUNT(*) FROM PromotionBogo pb2
                  WHERE pb2.PromotionId = P.PromotionId
                    AND pb2.ConditionType = ''ITEM''
                    AND pb2.ConditionItemId IS NOT NULL
              ) = 1
        ) sb ';

    SET @Qry += ' WHERE 1=1 ';

    IF @Filterby IS NOT NULL
        SET @Qry += ' AND P.PromotionType=''' + @Filterby + '''';

    IF @Search IS NOT NULL
        SET @Qry += ' AND (P.Name like ''%' + @Search + '%''
                        OR P.DisplayName like ''%' + @Search + '%''
                        OR P.PromotionType like ''%' + @Search + '%'')';

    IF @StartDate IS NOT NULL
        SET @Qry += N' AND (P.EndDate IS NULL OR P.EndDate >= '''+CONVERT(VARCHAR,@StartDate)+''') ';

    IF @EndDate IS NOT NULL
        SET @Qry += N' AND (P.StartDate IS NULL OR P.StartDate <= '''+CONVERT(VARCHAR,@EndDate)+''') ';

    -- Count mode
    IF @IsCount = 1
    BEGIN
        EXEC sp_executesql @Qry, N'@RCount int OUTPUT', @RCount=@TotalCount OUTPUT;
        RETURN;
    END

    -- Sorting (your style)
    IF @SortField IS NOT NULL
        SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder + '';
    ELSE
        SET @Qry += ' ORDER BY P.PromotionId DESC';

    -- Paging
    SET @Qry += ' OFFSET ' + CONVERT(VARCHAR(100), (@PageSize * (@Pageno - 1))) + ' ROWS
                 FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY ';

    EXEC (@Qry);
END
GO
