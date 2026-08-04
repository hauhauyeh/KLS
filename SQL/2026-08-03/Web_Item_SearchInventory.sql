SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Web_Item_SearchInventory]
    @SearchTerm NVARCHAR(100)
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
        WHERE i.ItemType = 'Inventory'
          AND i.Inactive = 0
          AND i.IsDeleted = 0
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
        CASE WHEN BucketRank = 0 THEN ItemName ELSE ItemCode END;
END
GO
