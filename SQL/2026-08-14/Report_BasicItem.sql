SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[Report_BasicItem] -- EXEC dbo.Report_BasicItem
AS
BEGIN
    SET NOCOUNT ON;

    -- Basic Item report:
    -- one row per active inventory item, grouped by View_Category.RootNode.
    -- UnitPackSize mirrors the existing SetPackingFormatter convention:
    -- case-style base unit + first active non-base split unit by ItemUnitId.
    SELECT
        i.ItemId,
        CAST(COALESCE(vc.RootNode, N'Uncategorized') AS NVARCHAR(500)) AS Category,
        vc.Sort0 AS CategorySort0,
        vc.Sort1 AS CategorySort1,
        vc.Sort2 AS CategorySort2,
        vc.Sort3 AS CategorySort3,
        vc.Sort4 AS CategorySort4,
        vc.Sort5 AS CategorySort5,
        i.ItemCode,
        i.ItemName,
        CAST(CASE
            WHEN bu.UnitName IS NULL THEN NULL
            WHEN bu.UnitName IN (N'cs', N'case', N'carton', N'ctn', N'crt')
                 AND au.UnitName IS NOT NULL
                 AND au.FactorToBase > 1
                 AND au.UnitName NOT IN (N'cs', N'case', N'carton', N'ctn', N'crt')
                THEN bu.UnitName + N' / ' + FORMAT(au.FactorToBase, N'0.######') + N' ' + au.UnitName
            ELSE bu.UnitName
        END AS NVARCHAR(100)) AS UnitPackSize,
        CAST(CASE
            WHEN i.IsMetricDimension = 1
                 AND i.CaseLength IS NOT NULL
                 AND i.CaseWidth IS NOT NULL
                 AND i.CaseHeight IS NOT NULL
                THEN FORMAT(i.CaseLength, N'0.##') + N' x '
                   + FORMAT(i.CaseWidth, N'0.##') + N' x '
                   + FORMAT(i.CaseHeight, N'0.##')
            ELSE NULL
        END AS NVARCHAR(80)) AS Dimension,
        CAST(CASE
            WHEN i.IsMetricWeight = 1
                 AND i.CaseWeight IS NOT NULL
                THEN FORMAT(i.CaseWeight, N'0.##')
            ELSE NULL
        END AS NVARCHAR(50)) AS [Weight]
    FROM dbo.Item AS i
    LEFT JOIN dbo.View_Category AS vc
        ON vc.CategoryId = i.CategoryId
    OUTER APPLY
    (
        SELECT TOP (1)
            LOWER(LTRIM(RTRIM(iu.Unit))) AS UnitName
        FROM dbo.ItemUnit AS iu
        WHERE iu.ItemId = i.ItemId
          AND iu.IsBaseUnit = 1
          AND iu.Inactive = 0
        ORDER BY iu.ItemUnitId
    ) AS bu
    OUTER APPLY
    (
        SELECT TOP (1)
            LOWER(LTRIM(RTRIM(iu.Unit))) AS UnitName,
            iu.FactorToBase
        FROM dbo.ItemUnit AS iu
        WHERE iu.ItemId = i.ItemId
          AND iu.IsBaseUnit = 0
          AND iu.Inactive = 0
        ORDER BY iu.ItemUnitId
    ) AS au
    WHERE i.IsDeleted = 0
      AND i.Inactive = 0
      AND i.ItemType = N'Inventory'
    ORDER BY
        vc.Sort0,
        vc.Sort1,
        vc.Sort2,
        vc.Sort3,
        vc.Sort4,
        vc.Sort5,
        COALESCE(vc.RootNode, N'Uncategorized'),
        i.ItemName,
        i.ItemCode;
END
GO
