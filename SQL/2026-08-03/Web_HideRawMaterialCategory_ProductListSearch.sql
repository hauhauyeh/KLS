SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Web_Item_SearchInventory]
    @SearchTerm NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

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
        WHERE i.ItemType = 'Inventory'
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
GO

CREATE OR ALTER PROCEDURE [dbo].[Web_Item_List]
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

    CREATE TABLE #HiddenWebCategories
    (
        CategoryId INT PRIMARY KEY
    );

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
    )
    INSERT INTO #HiddenWebCategories(CategoryId)
    SELECT DISTINCT CategoryId
    FROM HiddenCategoryTree
    OPTION (MAXRECURSION 100);

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

    SET @Qry += ' AND i.ItemType = ''Inventory'' and i.Inactive=0
        AND (i.CategoryId IS NULL OR NOT EXISTS
        (
            SELECT 1
            FROM #HiddenWebCategories hwc
            WHERE hwc.CategoryId = i.CategoryId
        )) '

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
