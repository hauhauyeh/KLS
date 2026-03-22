CREATE PROCEDURE [dbo].[Item_SearchByTerm]
    @SearchTerm NVARCHAR(100),
    @IsActiveOnly BIT
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
            i.Last3M,
            i.Inactive,
            CHARINDEX(@SearchTerm, i.ItemCode + ' ' + i.ItemName + ' ' + ISNULL(i.ItemSearchTag, '')) AS DescLoc,
            iu.Unit AS BaseUnit,
            im.ThumbnailPath
        FROM Item AS i
        LEFT JOIN ItemUnit AS iu
            ON i.ItemId = iu.ItemId
           AND iu.IsBaseUnit = 1
        LEFT JOIN ItemImage AS im ON i.ItemId = im.ItemId AND im.IsPrimary = 1
        WHERE
        @IsActiveOnly = 0
        OR (i.Inactive = 0 AND i.IsDeleted = 0)
    ),
    ctefinal AS
    (
        SELECT *, 1 AS rn FROM cte WHERE ItemCode = @SearchTerm
        UNION
        SELECT *, 2 AS rn FROM cte WHERE DescLoc > 0 AND ItemCode <> @SearchTerm
    )
    SELECT TOP (100)
        ItemId, ItemCode, ItemName, BaseUnit, LCloseQty, Inactive,
        NULL AS ItemSearchTag,
        CAST(NULL AS DATETIME) AS LastOrderDate,
        CAST(NULL AS DECIMAL(18,4)) AS LastOrderQty,
        CAST(NULL AS NVARCHAR(50)) AS LastOrderUnit,
        ThumbnailPath AS PrimaryImageUrl
    FROM ctefinal
    -- ORDER BY rn, DescLoc, ItemName;
    ORDER BY rn, ISNULL(Last3M, 0) DESC, DescLoc, ItemName;
END
