SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Report_ItemAnalysis - Item sales analysis (all customers): qty, amount, cost, margin per item.
--   Groupable by Category / Storage / None; sortable by most-ordered / item name / sales% / expiry.
--   Cost is the recognized COGS from the journal (TransactionJournalDetail @COGS) -- NOT FIFOCost,
--   which is unreliable on shipped lines.
-- 2026-06-26: rebuilt from the retired Report_SalesbyItem (orphaned; the legacy Sales-group page
--   wrongly reached the customer SP, so its item search filtered customers). This version adds:
--   ItemCode (+ ItemCode search), category-subtree filter (@CategoryId), Storage/Last3M/Expiry
--   columns, and the @GroupBy / expanded @Sortby options. The predecessor is dropped below.
-- Prior: -- Report_SalesbyItem - Sales by item (all customers) with qty, amount, cost, margin
--        -- Fixed JOIN bug: s.ItemId = i.ItemId (was i.ItemCode)  [retired -> see dated baseline]

-- retire the orphaned predecessor, then (re)create under the new name
DROP PROCEDURE IF EXISTS [dbo].[Report_SalesbyItem]
GO
DROP PROCEDURE IF EXISTS [dbo].[Report_ItemAnalysis]
GO
CREATE PROCEDURE [dbo].[Report_ItemAnalysis] -- EXEC Report_ItemAnalysis @StartDate='2026-01-01',@EndDate='2026-06-30',@GroupBy='category',@Sortby='mostordered'
-- EXEC Report_ItemAnalysis @StartDate='2026-01-01',@EndDate='2026-06-30',@Search='beef'
-- EXEC Report_ItemAnalysis @StartDate='2026-01-01',@EndDate='2026-06-30',@CategoryId=5,@GroupBy='storage',@Sortby='expiry'
(
    @Search     NVARCHAR(100) = NULL,        -- matches ItemName OR ItemCode
    @CategoryId INT           = NULL,        -- subtree root; NULL = all items (incl. uncategorized)
    @StartDate  DATE          = NULL,
    @EndDate    DATE          = NULL,
    @GroupBy    NVARCHAR(20)  = 'category',  -- category | storage | none
    @Sortby     NVARCHAR(50)  = NULL         -- mostordered (gross $) | itemname | qty | expiry
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TotalSales DECIMAL(18,2);
    DECLARE @INVAccountId INT;
    DECLARE @ISALEAccountId INT;
    DECLARE @COGSAccountId INT;
    SELECT @INVAccountId   = AccountId FROM Account WHERE AccountCode = '@INV';
    SELECT @ISALEAccountId = AccountId FROM Account WHERE AccountCode = '@ISALE';
    SELECT @COGSAccountId  = AccountId FROM Account WHERE AccountCode = '@COGS';

    -- 2026-06-26: resolve the category subtree once -- all descendants of @CategoryId via the
    -- ItemCategory ParentId tree. Stays empty when @CategoryId IS NULL, in which case the filter
    -- below short-circuits on "@CategoryId IS NULL" and keeps ALL items (incl. uncategorized).
    DECLARE @CatTree TABLE (CategoryId INT PRIMARY KEY);
    IF @CategoryId IS NOT NULL
    BEGIN
        ;WITH SubCat AS
        (
            SELECT CategoryId FROM ItemCategory WHERE CategoryId = @CategoryId
            UNION ALL
            SELECT c.CategoryId
            FROM ItemCategory c
            INNER JOIN SubCat t ON c.ParentId = t.CategoryId
        )
        INSERT INTO @CatTree (CategoryId)
        SELECT CategoryId FROM SubCat
        OPTION (MAXRECURSION 0);   -- guard deep trees
    END

    -- Journal-sourced figures per item: Qty from the @INV line, Amount from @ISALE, Cost from @COGS.
    ;WITH SalesCTE AS
    (
        SELECT
            td.ItemId,
            ISNULL(SUM(CASE WHEN td.AccountId = @INVAccountId   THEN td.Qty    ELSE 0 END), 0) AS Qty,
            ISNULL(SUM(CASE WHEN td.AccountId = @ISALEAccountId THEN td.Amount ELSE 0 END), 0) AS Amount,
            ISNULL(SUM(CASE WHEN td.AccountId = @COGSAccountId  THEN td.Amount ELSE 0 END), 0) AS Cost
        FROM TransactionJournal t
        INNER JOIN TransactionJournalDetail td ON t.TxId = td.TxId
        WHERE
            t.SourceDocType = 'Sales'
            AND (@StartDate IS NULL OR t.TxDate >= @StartDate)
            AND (@EndDate   IS NULL OR t.TxDate <= @EndDate)
        GROUP BY td.ItemId
    )
    SELECT
        i.CategoryId AS Cat,
        s.ItemId,
        i.ItemCode,                       -- 2026-06-26: added -- the report "Code" column needs it
        i.ItemName,
        v.Cat0,
        v.Cat1,
        v.Sort0,
        v.Sort1,
        st.DisplayName AS StorageName,    -- 2026-06-26: storage label = ItemStorage.DisplayName (no StorageName col)
        i.Last3M,                         -- 2026-06-26: trailing-3-month volume, for 'mostordered' sort
        i.ExpiryDate,                     -- 2026-06-26: for 'expiry' sort + display
        s.Qty,
        s.Amount,
        CAST(0 AS MONEY) AS SalesPerc,
        s.Cost,
        (s.Amount - s.Cost) AS GrossMargin,
        CASE WHEN s.Amount <> 0
             THEN (s.Amount - s.Cost) / s.Amount
             ELSE 0 END AS GrossMarginPerc
    INTO #Result
    FROM SalesCTE s
    INNER JOIN Item i ON s.ItemId = i.ItemId
    LEFT JOIN View_Category v ON v.CategoryId = i.CategoryId
    LEFT JOIN ItemStorage st  ON st.StorageId = i.StorageId   -- 2026-06-26: LEFT so unstored items aren't dropped
    WHERE
        s.Qty <> 0
        -- 2026-06-26: search now matches ItemName OR ItemCode (was ItemName only)
        AND (@Search IS NULL OR i.ItemName LIKE '%' + @Search + '%' OR i.ItemCode LIKE '%' + @Search + '%')
        -- 2026-06-26: category subtree filter; @CategoryId NULL -> no predicate (all items, uncategorized kept)
        AND (@CategoryId IS NULL OR i.CategoryId IN (SELECT CategoryId FROM @CatTree));

    SELECT @TotalSales = SUM(Amount) FROM #Result;
    UPDATE #Result
    SET SalesPerc = CASE
                        WHEN @TotalSales <> 0
                        THEN Amount / @TotalSales
                        ELSE 0
                    END;

    -- 2026-06-26: ORDER BY honors the chosen grouping (category Sort0/Sort1, or storage name, or
    -- none) THEN the chosen sort field. @Grpbycat retired in favor of @GroupBy. Each CASE is an
    -- independent ORDER BY term; a CASE that is NULL for every row is inert (no ordering effect).
    SELECT *
    FROM #Result
    ORDER BY
        CASE WHEN @GroupBy = 'category' THEN Sort0       END,
        CASE WHEN @GroupBy = 'category' THEN Sort1       END,
        CASE WHEN @GroupBy = 'storage'  THEN StorageName END,
        CASE WHEN @Sortby = 'mostordered' THEN Amount    END DESC,   -- 'most ordered' = gross $ (revenue) in range
        CASE WHEN @Sortby = 'qty'         THEN Qty       END DESC,   -- most units (cases) in range
        CASE WHEN @Sortby = 'expiry'      THEN ExpiryDate END,
        ItemName;   -- final tiebreak + the 'itemname' sort
    DROP TABLE #Result;
END
GO
