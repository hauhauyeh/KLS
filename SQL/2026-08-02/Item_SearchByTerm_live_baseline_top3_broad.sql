

CREATE   PROCEDURE [dbo].[Item_SearchByTerm]
    @SearchTerm NVARCHAR(100),
    @ShowInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH BaseItems AS
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
        WHERE (@ShowInactive = 1 OR i.Inactive = 0)
          AND i.IsDeleted = 0
    ),
    CodeMatches AS
    (
        SELECT TOP (3)
            b.ItemId,
            b.ItemCode,
            b.ItemName,
            b.LCloseQty,
            b.Inactive,
            b.BaseUnit,
            b.ThumbnailPath,
            0 AS BucketRank,
            CASE
                WHEN b.ItemCode = @SearchTerm THEN 1
                WHEN b.ItemCode LIKE @SearchTerm + '%' THEN 2
                WHEN b.ItemCode LIKE '%' + @SearchTerm + '%' THEN 3
            END AS SearchRank,
            CASE
                WHEN b.ItemCode = @SearchTerm THEN 0
                WHEN b.ItemCode LIKE @SearchTerm + '%' THEN 0
                WHEN b.ItemCode LIKE '%' + @SearchTerm + '%' THEN CHARINDEX(@SearchTerm, b.ItemCode)
            END AS SearchLoc
        FROM BaseItems AS b
        WHERE b.ItemCode = @SearchTerm
           OR b.ItemCode LIKE @SearchTerm + '%'
           OR b.ItemCode LIKE '%' + @SearchTerm + '%'
        ORDER BY
            CASE
                WHEN b.ItemCode = @SearchTerm THEN 1
                WHEN b.ItemCode LIKE @SearchTerm + '%' THEN 2
                WHEN b.ItemCode LIKE '%' + @SearchTerm + '%' THEN 3
            END,
            CASE
                WHEN b.ItemCode = @SearchTerm THEN 0
                WHEN b.ItemCode LIKE @SearchTerm + '%' THEN 0
                WHEN b.ItemCode LIKE '%' + @SearchTerm + '%' THEN CHARINDEX(@SearchTerm, b.ItemCode)
            END,
            LEN(b.ItemCode),
            b.ItemCode
    ),
    TextMatches AS
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
            CASE
                WHEN b.ItemName LIKE @SearchTerm + '%' THEN 4
                WHEN b.ItemName LIKE '%' + @SearchTerm + '%' THEN 5
                WHEN ISNULL(b.ItemSearchTag, '') LIKE '%' + @SearchTerm + '%' THEN 6
            END AS SearchRank,
            CASE
                WHEN b.ItemName LIKE @SearchTerm + '%' THEN 0
                WHEN b.ItemName LIKE '%' + @SearchTerm + '%' THEN CHARINDEX(@SearchTerm, b.ItemName)
                WHEN ISNULL(b.ItemSearchTag, '') LIKE '%' + @SearchTerm + '%' THEN CHARINDEX(@SearchTerm, ISNULL(b.ItemSearchTag, ''))
            END AS SearchLoc
        FROM BaseItems AS b
        WHERE NOT EXISTS (SELECT 1 FROM CodeMatches AS cm WHERE cm.ItemId = b.ItemId)
          AND (
                 b.ItemName LIKE @SearchTerm + '%'
              OR b.ItemName LIKE '%' + @SearchTerm + '%'
              OR ISNULL(b.ItemSearchTag, '') LIKE '%' + @SearchTerm + '%'
          )
    ),
    RankedResults AS
    (
        SELECT * FROM CodeMatches
        UNION ALL
        SELECT * FROM TextMatches
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
        CASE WHEN BucketRank = 0 THEN ItemName ELSE ItemCode END;
END