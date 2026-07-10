
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B-Phase2-Slice3-Promotion_GetAllList: Class-B derived-price ROUND flip (setting-gated).
--   The effective per-unit promo price (AfterPromoPrice) is a division -> derived. Gate its ROUND on
--   PRICE_DISPLAY_DECIMALS (guard missing/0/2/invalid -> 2, =4 -> 4). setting=2: byte-identical (ROUND(,2)).
--   Injected into the dynamic SQL as a VALIDATED int (2 or 4) -> no injection risk. Money/other cols untouched.
CREATE OR ALTER PROCEDURE [dbo].[Promotion_GetAllList] --[dbo].[Promotion_GetAllList] Null,Null,Null,Null,Null,Null,Null,Null,0,0
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

    -- 2026-07-09 Slice-3: read the active price-decimals mode (guard missing/0/2/invalid -> 2, =4 -> 4).
    -- Forced to 2 or 4 before any string concat below -> the dynamic-SQL injection is not an injection risk.
    DECLARE @PriceDecimals INT;
    SELECT @PriceDecimals = TRY_CAST(SettingValue AS INT) FROM dbo.SystemSetting WHERE SettingKey = 'PRICE_DISPLAY_DECIMALS';
    SET @PriceDecimals = CASE WHEN @PriceDecimals = 4 THEN 4 ELSE 2 END;

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
                    THEN ROUND(pb.PromoPrice * pb.ConditionQty * 1.0 / (pb.ConditionQty + pb.RewardQty), ' + CONVERT(NVARCHAR(1), @PriceDecimals) + ')
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
