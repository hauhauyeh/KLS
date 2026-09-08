
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[Item_SearchByTerm] -- EXEC dbo.Item_SearchByTerm @SearchTerm = N'1500''', @ShowInactive = 1, @ShowNonInventory = 1
    @SearchTerm NVARCHAR(100),
    @ShowInactive BIT = 0,
    @ShowNonInventory BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Term NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@SearchTerm)), N'');
    DECLARE @TermLike NVARCHAR(202) = CASE WHEN @Term IS NULL THEN NULL ELSE N'%' + @Term + N'%' END;
    DECLARE @TermPrefix NVARCHAR(101) = CASE WHEN @Term IS NULL THEN NULL ELSE @Term + N'%' END;
    DECLARE @TermItemId INT = CASE
        WHEN @Term LIKE N'#%' THEN TRY_CAST(NULLIF(LTRIM(RTRIM(SUBSTRING(@Term, 2, 100))), N'') AS INT)
        ELSE NULL
    END;

    ;WITH BaseItems AS
    (
        SELECT
            i.ItemId,
            i.ItemCode,
            i.ItemName,
            ISNULL(i.LCloseQty, 0) AS LCloseQty,
            i.Inactive,
            iu.Unit AS BaseUnit,
            i.ItemName2,
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
        WHERE i.ItemType IN ('Inventory', 'NonInventory')
          -- 2026-09-08: N toggle is authoritative; exact id no longer bypasses it.
          -- Old: AND (@TermItemId IS NOT NULL OR @ShowNonInventory = 1 OR i.ItemType = 'Inventory')
          AND (@ShowNonInventory = 1 OR i.ItemType = 'Inventory')
          AND (@ShowInactive = 1 OR i.Inactive = 0)
          AND i.IsDeleted = 0
    ),
    RankedResults AS
    (
        SELECT
            b.ItemId,
            b.ItemCode,
            b.ItemName,
            b.LCloseQty,
            b.Inactive,
            b.BaseUnit,
            b.ThumbnailPath,
            CASE
                WHEN @TermItemId IS NOT NULL AND b.ItemId = @TermItemId THEN 0
                WHEN b.ItemCode = @Term THEN 1
                WHEN b.ItemCode LIKE @TermPrefix THEN 2
                WHEN b.ItemCode LIKE @TermLike THEN 3
                WHEN b.ItemName LIKE @TermLike THEN 4
                WHEN ISNULL(b.ItemName2, '') LIKE @TermLike THEN 5
                WHEN ISNULL(b.ItemSearchTag, '') LIKE @TermLike THEN 6
                WHEN EXISTS (
                    SELECT 1
                    FROM dbo.ItemUnit iuExact
                    WHERE iuExact.ItemId = b.ItemId
                      AND ISNULL(iuExact.Barcode, '') = @Term
                ) THEN 7
                WHEN EXISTS (
                    SELECT 1
                    FROM dbo.ItemUnit iuBarcode
                    WHERE iuBarcode.ItemId = b.ItemId
                      AND ISNULL(iuBarcode.Barcode, '') LIKE @TermLike
                ) THEN 8
                ELSE 99
            END AS SearchRank,
            CASE
                WHEN b.ItemCode = @Term THEN 0
                WHEN b.ItemCode LIKE @TermPrefix THEN 0
                WHEN b.ItemCode LIKE @TermLike THEN CHARINDEX(@Term, b.ItemCode)
                WHEN b.ItemName LIKE @TermLike THEN CHARINDEX(@Term, b.ItemName)
                WHEN ISNULL(b.ItemName2, '') LIKE @TermLike THEN CHARINDEX(@Term, ISNULL(b.ItemName2, ''))
                WHEN ISNULL(b.ItemSearchTag, '') LIKE @TermLike THEN CHARINDEX(@Term, ISNULL(b.ItemSearchTag, ''))
                ELSE 999
            END AS SearchLoc
        FROM BaseItems AS b
        WHERE @Term IS NOT NULL
          AND (
              (@TermItemId IS NOT NULL AND b.ItemId = @TermItemId)
              OR (
                  @TermItemId IS NULL
                  AND (
                      b.ItemCode LIKE @TermLike
                      OR b.ItemName LIKE @TermLike
                      OR ISNULL(b.ItemName2, '') LIKE @TermLike
                      OR ISNULL(b.ItemSearchTag, '') LIKE @TermLike
                      OR EXISTS (
                          SELECT 1
                          FROM dbo.ItemUnit iuMatch
                          WHERE iuMatch.ItemId = b.ItemId
                            AND ISNULL(iuMatch.Barcode, '') LIKE @TermLike
                      )
                  )
              )
          )
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
        SearchRank,
        SearchLoc,
        LEN(ItemCode),
        ItemCode,
        ItemName;
END
