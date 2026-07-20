-- =============================================================================
-- Web_Item_List -- add iu.FactorToBase + iu.MultipleToBase to the unit rows.
-- 2026-07-20 (web-unit-stock-restriction plan, Phase 1a): the web frontend needs the
--   full unit ratio (BaseQty = Qty * MultipleToBase / FactorToBase) to compute per-unit
--   whole-unit stock availability under WEB_ENFORCE_STOCK_LIMIT. MultipleToBase is the
--   live source of truth on ItemUnit (never snapshotted on transaction rows).
-- DEPLOY ORDER: run this WITH/BEFORE the API deploy -- ItemWebRowList is an EF keyless
--   type materialized by column name and fails if these columns are missing.
-- Baseline: KLS/SQL/2026-06-22/02-Web_Item_List-BaseUnitOnly.sql
-- =============================================================================
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Web_Item_List]
    @Pageno int,
    @Pagesize int,
    @PayeeId int,
    @Search nvarchar(50),
    @InStockOnly BIT,
    @CategoryId INT,
    @IsWishList BIT,
    @SortField NVARCHAR(50),
    @IsCount bit,
    @TotalCount int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX) = ''
    DECLARE @Offset INT = @Pagesize * (@Pageno - 1)

    DECLARE @ShareQuoteId INT
    DECLARE @HasOwnList BIT
    DECLARE @SelectedQuote INT
    DECLARE @PriceShow NVARCHAR(10)
    DECLARE @BaseUnitOnly BIT = 0

    SELECT @ShareQuoteId=ShareQuoteId,
    @HasOwnList=HasOwnList,
    @PriceShow=PriceShow
    FROM Customer WHERE PayeeId= @PayeeId

    SET @PriceShow = ISNULL(@PriceShow, 'Show')

    SELECT @BaseUnitOnly = CASE WHEN SettingValue = 'true' THEN 1 ELSE 0 END
    FROM SystemSetting WHERE SettingKey = 'WEB_SELL_BASEUNIT_ONLY'

    SET @SelectedQuote = CASE WHEN @HasOwnList = 0 AND @ShareQuoteId IS NOT NULL THEN @ShareQuoteId
                         ELSE @PayeeId END

    IF @IsCount = 1
        SET @Qry = 'SELECT @RCount = COUNT(i.ItemId) '
    ELSE
        SET @Qry = '
        CREATE TABLE #PagedItems
        (
            ItemId INT PRIMARY KEY
        )

        INSERT INTO #PagedItems(ItemId)
        SELECT i.ItemId '

    SET @Qry += '
    FROM Item i
    LEFT JOIN View_Category v ON i.CategoryId = v.CategoryId'

    IF @IsWishList = 1
        SET @Qry += '
        WHERE EXISTS
        (
            SELECT 1
            FROM ItemQuote iq
            WHERE iq.ItemId = i.ItemId
              AND iq.PayeeId = ' + CONVERT(VARCHAR,@SelectedQuote) + '
        )'
    ELSE
        SET @Qry += ' WHERE 1=1 '

    SET @Qry += ' AND i.ItemType = ''Inventory'' and i.Inactive=0 '

    IF @CategoryId IS NOT NULL AND @CategoryId > 0
        SET @Qry += ' AND (i.CategoryId = ' + CAST(@CategoryId AS VARCHAR) + '
                   OR v.ParentId = ' + CAST(@CategoryId AS VARCHAR) + ')'

    IF @Search IS NOT NULL AND LTRIM(RTRIM(@Search)) <> ''
    BEGIN
        SET @Search = REPLACE(@Search,'''','''''')

        SET @Qry += '
        AND (
            i.ItemCode LIKE ''%' + @Search + '%''
            OR i.ItemName LIKE ''%' + @Search + '%''
            OR i.ItemSearchTag LIKE ''%' + @Search + '%''
            OR CAST(i.ItemId AS NVARCHAR(20)) LIKE ''' + @Search + '%''
        )'
    END

    IF @InStockOnly = 1
        SET @Qry += ' AND i.LCloseQty>0'

    IF @IsCount = 1
    BEGIN
        EXEC sp_executesql
            @Qry,
            N'@RCount INT OUTPUT',
            @RCount = @TotalCount OUTPUT
        RETURN
    END

    IF @SortField IS NOT NULL
    BEGIN
        IF @SortField='az'
            SET @Qry += ' ORDER BY ItemName'
        ELSE IF @SortField='za'
            SET @Qry += ' ORDER BY ItemName DESC'
        ELSE IF @SortField='exp'
            SET @Qry += ' ORDER BY ExpiryDate'
    END
    ELSE
        SET @Qry += ' ORDER BY v.RootNode, ItemName '

    SET @Qry += ' OFFSET ' + CONVERT(VARCHAR(100), @Offset) + ' ROWS
    FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY

    SELECT
        i.ItemId,
        i.ItemCode,
        i.ItemName,
        i.ItemName2,
        i.ItemLongDesc,
        i.SetPacking,
        i.PackSize,
        i.LCloseQty,
        i.ExpiryDate,
        iu.ItemUnitId,
        iu.Unit,
        iu.Barcode,
        iu.IsBaseUnit,
        iu.IsDefaultSalesUnit,
        iu.FactorToBase,
        iu.MultipleToBase,
        iu.MSRP,
        iu.MarketPrice,
        CASE
            WHEN '''+@PriceShow+''' = ''Hide'' THEN NULL
            WHEN '''+@PriceShow+''' = ''OwnList'' AND NOT EXISTS (
                SELECT 1 FROM ItemQuote iq WHERE iq.PayeeId = '+CAST(@SelectedQuote AS VARCHAR(20))+' AND iq.ItemId = i.ItemId
            ) THEN NULL
            ELSE p.Price
        END AS Price,
        CASE
            WHEN '''+@PriceShow+''' = ''Hide'' THEN NULL
            WHEN '''+@PriceShow+''' = ''OwnList'' AND NOT EXISTS (
                SELECT 1 FROM ItemQuote iq WHERE iq.PayeeId = '+CAST(@SelectedQuote AS VARCHAR(20))+' AND iq.ItemId = i.ItemId
            ) THEN NULL
            ELSE p.Discount
        END AS Discount,
        CASE WHEN img.Has300 = 1
            THEN CONCAT(''/Images/items/'', img.ItemId, ''/'', img.ImageIndex, ''-300.png'')
            ELSE NULL END AS PrimaryImageUrl
    FROM #PagedItems pi
    INNER JOIN Item i ON i.ItemId = pi.ItemId
    INNER JOIN ItemUnit iu ON iu.ItemId = i.ItemId AND iu.Inactive = 0' +
    CASE WHEN @BaseUnitOnly = 1 THEN ' AND iu.IsBaseUnit = 1' ELSE '' END + '
    LEFT JOIN View_Category v ON i.CategoryId = v.CategoryId
    OUTER APPLY
    (
        SELECT TOP 1 im.ItemId, im.ImageIndex, im.Has300
        FROM ItemImage im
        WHERE im.ItemId = i.ItemId
        ORDER BY im.IsPrimary DESC, im.SortOrder ASC, im.ImageId ASC
    ) img
    OUTER APPLY
    (
        SELECT *
        FROM dbo.Fn_GetPrice(' + CAST(@PayeeId AS VARCHAR(20)) + ', i.ItemId, iu.ItemUnitId)
    ) p '

    IF @SortField IS NOT NULL
    BEGIN
        IF @SortField='az'
            SET @Qry += ' ORDER BY ItemName,iu.ItemUnitId'
        ELSE IF @SortField='za'
            SET @Qry += ' ORDER BY ItemName DESC,iu.ItemUnitId'
        ELSE IF @SortField='exp'
            SET @Qry += ' ORDER BY ExpiryDate,iu.ItemUnitId'
    END
    ELSE
        SET @Qry += ' ORDER BY v.RootNode, ItemName, iu.ItemUnitId '

    SET @Qry += ' DROP TABLE #PagedItems '

    EXEC(@Qry)
END
GO
