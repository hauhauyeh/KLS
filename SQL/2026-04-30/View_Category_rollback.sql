-- Rollback: Restore View_Category without Sort0–Sort5 columns
ALTER VIEW [dbo].[View_Category]
AS
WITH CatTree AS
(
    -- Roots
    SELECT
        ic.CategoryId,
        ic.ParentId,
        ic.SortOrder,
        ic.CategoryName,
        ic.ForeignName,
        ic.DisplayName,
        ic.InvoiceName,
        CAST(0 AS int) AS TreeLevel,

        CAST(ic.CategoryName AS nvarchar(255)) AS Cat0,
        CAST(NULL AS nvarchar(255)) AS Cat1,
        CAST(NULL AS nvarchar(255)) AS Cat2,
        CAST(NULL AS nvarchar(255)) AS Cat3,
        CAST(NULL AS nvarchar(255)) AS Cat4,
        CAST(NULL AS nvarchar(255)) AS Cat5,

        CAST(ic.CategoryName AS nvarchar(max)) AS RootNode
    FROM dbo.ItemCategory AS ic
    WHERE ic.ParentId IS NULL OR ic.CategoryId = ic.ParentId

    UNION ALL

    -- Children
    SELECT
        c.CategoryId,
        c.ParentId,
        c.SortOrder,
        c.CategoryName,
        c.ForeignName,
        c.DisplayName,
        c.InvoiceName,
        p.TreeLevel + 1,

        p.Cat0,
        CASE WHEN p.TreeLevel + 1 = 1 THEN c.CategoryName ELSE p.Cat1 END,
        CASE WHEN p.TreeLevel + 1 = 2 THEN c.CategoryName ELSE p.Cat2 END,
        CASE WHEN p.TreeLevel + 1 = 3 THEN c.CategoryName ELSE p.Cat3 END,
        CASE WHEN p.TreeLevel + 1 = 4 THEN c.CategoryName ELSE p.Cat4 END,
        CASE WHEN p.TreeLevel + 1 = 5 THEN c.CategoryName ELSE p.Cat5 END,

        CAST(p.RootNode + N' -> ' + c.CategoryName AS nvarchar(max)) AS RootNode
    FROM dbo.ItemCategory AS c
    INNER JOIN CatTree AS p
        ON p.CategoryId = c.ParentId
       AND c.CategoryId <> c.ParentId
)
SELECT
    CategoryId,
    ParentId,
    SortOrder,
    CategoryName,
    DisplayName,
    ForeignName,
    InvoiceName,
    TreeLevel,
    RootNode,
    Cat0, Cat1, Cat2, Cat3, Cat4, Cat5
FROM CatTree;
