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
            iu.Unit AS BaseUnit,
            CASE
                WHEN im.Has300 = 1
                THEN CONCAT('/Images/items/', im.ItemId, '/', im.ImageIndex, '-300.png')
                ELSE NULL
            END AS ThumbnailPath,
            CASE
                WHEN i.ItemCode = @SearchTerm THEN 1
                WHEN i.ItemCode LIKE @SearchTerm + '%' THEN 2
                WHEN i.ItemCode LIKE '%' + @SearchTerm + '%' THEN 3
                WHEN i.ItemName LIKE @SearchTerm + '%' THEN 4
                WHEN i.ItemName LIKE '%' + @SearchTerm + '%' THEN 5
                WHEN ISNULL(i.ItemSearchTag, '') LIKE '%' + @SearchTerm + '%' THEN 6
                ELSE 99
            END AS SearchRank,
            CASE
                WHEN i.ItemCode = @SearchTerm THEN 0
                WHEN i.ItemCode LIKE @SearchTerm + '%' THEN 0
                WHEN i.ItemCode LIKE '%' + @SearchTerm + '%' THEN CHARINDEX(@SearchTerm, i.ItemCode)
                WHEN i.ItemName LIKE @SearchTerm + '%' THEN 0
                WHEN i.ItemName LIKE '%' + @SearchTerm + '%' THEN CHARINDEX(@SearchTerm, i.ItemName)
                WHEN ISNULL(i.ItemSearchTag, '') LIKE '%' + @SearchTerm + '%' THEN CHARINDEX(@SearchTerm, ISNULL(i.ItemSearchTag, ''))
                ELSE 999
            END AS SearchLoc
        FROM Item AS i
        LEFT JOIN ItemUnit AS iu
            ON i.ItemId = iu.ItemId
           AND iu.IsBaseUnit = 1
        LEFT JOIN ItemImage AS im
            ON i.ItemId = im.ItemId
           AND im.IsPrimary = 1
        WHERE (@ShowInactive = 1 OR i.Inactive = 0)
          AND i.IsDeleted = 0
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
    FROM cte
    WHERE SearchRank < 99
    ORDER BY
        SearchRank,
        SearchLoc,
        LEN(ItemCode),
        ItemCode,
        ItemName;
END
GO
