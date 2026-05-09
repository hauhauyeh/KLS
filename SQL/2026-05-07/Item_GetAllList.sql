-- Item_GetAllList rev 2026-05-07
-- Visibility refactor:
--   - Replaces the @Visibility NVARCHAR(20) parameter with two BIT flags
--     @ShowInactive and @ShowDeleted that map directly to the new I/D
--     checkboxes on the product list page. The previous 4-way string branch
--     is preserved as a comment for reference.
--   - Adds IsDeleted to the #itmtbl temp table and to the projected SELECT,
--     so the frontend can dim deleted rows the same way it dims inactive
--     rows (single tr.inactive class with i.Inactive || i.IsDeleted).
--   - All other filters and post-processing untouched.
--
-- Workflow: 5-step SQL workflow per CLAUDE.md. This file is the workspace-
-- root scratch; baseline is at KLS\SQL\2026-05-07\Item_GetAllList_live_baseline.sql.

-- One-time baseline rename (skipped if _prev already exists from a prior round).
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Item_GetAllList')
   AND NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Item_GetAllList_prev')
    EXEC sp_rename 'Item_GetAllList', 'Item_GetAllList_prev';
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Item_GetAllList')
    DROP PROCEDURE dbo.Item_GetAllList;
GO

CREATE PROCEDURE [dbo].[Item_GetAllList]
(
    @Pageno        INT,
    @Pagesize      INT,
    @Search        NVARCHAR(200),
    @StartDate     DATE,
    @EndDate       DATE,
    @VendorId      INT,
    @Container     NVARCHAR(50),
    @CategoryId    INT = NULL,
    @Filterby      NVARCHAR(50),
    @Id            INT,
    @SortField     NVARCHAR(50),
    @SortOrder     NVARCHAR(50),
    @IsCount       BIT,
    @TotalCount    INT OUTPUT,
    -- Old @Visibility NVARCHAR(20) replaced by two ambient bits below.
    -- @ShowInactive: when 1, results include rows where Inactive = 1.
    --                Default 0 keeps the page list active-only as before.
    -- @ShowDeleted:  when 1, results include rows where IsDeleted = 1.
    --                Default 0 hides deleted rows -- preserves prior behavior
    --                for any caller that wasn't passing @Visibility.
    @ShowInactive  BIT = 0,
    @ShowDeleted   BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);
    DECLARE @2year DATE = DATEADD(YEAR, -2, GETDATE());

    CREATE TABLE #itmtbl
    (
        Id INT IDENTITY(1,1),
        ItemId INT,
        ItemCode NVARCHAR(50),
        ItemName NVARCHAR(255),
        ItemName2 NVARCHAR(255),
        SetPacking NVARCHAR(100),
        LastCostDate DATE,
        ItemUnitId INT,
        BaseUnit NVARCHAR(50),
        BaseRecentCost DECIMAL(18,2),
        BaseP1 DECIMAL(18,2),
        SaftyInventory DECIMAL(18,2),
        PreferredVendorId INT,
        VendorName NVARCHAR(255),
        IsHighlighted BIT,
        Inactive BIT,
        IsDeleted BIT,           -- NEW 2026-05-07: lets frontend dim deleted rows.
        ExpiryDate DATE,
        LCloseQty DECIMAL(18,2),
        LAvgCost DECIMAL(18,2),
        LInventoryValue DECIMAL(18,2),
        CaseWeight DECIMAL(18,2),
        Last3M DECIMAL(18,2),
        M0 DECIMAL(18,2),
        M1 DECIMAL(18,2),
        M2 DECIMAL(18,2),
        M3 DECIMAL(18,2),
        YTD DECIMAL(18,2),
        YTDSalesPercent DECIMAL(18,4),
        RecentCostPercent DECIMAL(18,4),
        FutureQty DECIMAL(18,2),
        OnHandQty DECIMAL(18,2),
        UpcomingQty DECIMAL(18,2),
        LastAdjDate DATE,
        PrimaryImageUrl NVARCHAR(300),
        CategoryId INT,
        FullCategoryPath NVARCHAR(500),
        StorageId INT,
        StorageName NVARCHAR(255),
        ActualSaftyInventory DECIMAL(18,2),
        RefillInventory DECIMAL(18,2),
        CaseLength DECIMAL(18,2),
        CaseWidth DECIMAL(18,2),
        CaseHeight DECIMAL(18,2),
        CaseVolumeInCubicMeter DECIMAL(18,4),
        IsVolumeManual BIT
    );

    IF @IsCount = 1
        SET @Qry = 'SELECT @RCount = COUNT(i.ItemId)';
    ELSE
        SET @Qry = '
            SELECT
                i.ItemId,
                i.ItemCode,
                i.ItemName,
                i.ItemName2,
                i.SetPacking,
                NULL AS LastCostDate,
                bu.ItemUnitId,
                bu.Unit,
                bu.RecentCost,
                bu.P1,
                i.SaftyInventory,
                i.PreferredVendorId,
                p.PayeeName,
                i.IsHighlighted,
                i.Inactive,
                i.IsDeleted,                          -- NEW 2026-05-07
                i.ExpiryDate,
                i.LCloseQty,
                i.LAvgCost,
                i.LInventoryValue,
                i.CaseWeight,
                i.Last3M,
                i.M0,
                i.M1,
                i.M2,
                i.M3,
                i.YTD,
                i.YTDSalesPercent,
                NULL AS RecentCostPercent,
                NULL AS FutureQty,
                NULL AS OnHandQty,
                NULL AS UpcomingQty,
                NULL AS LastAdjDate,
                CASE
                    WHEN im.ImageId IS NOT NULL AND im.Has300 = 1
                        THEN ''/Images/items/'' + CAST(im.ItemId AS VARCHAR(10)) + ''/'' + CAST(im.ImageIndex AS VARCHAR(10)) + ''-300.png''
                    ELSE NULL
                END,
                i.CategoryId,
                ISNULL(v.RootNode, '''') AS FullCategoryPath,
                i.StorageId,
                s.DisplayName AS StorageName,
                i.ActualSaftyInventory,
                i.RefillInventory,
                i.CaseLength,
                i.CaseWidth,
                i.CaseHeight,
                i.CaseVolumeInCubicMeter,
                i.IsVolumeManual';

    SET @Qry += '
        FROM Item AS i
        OUTER APPLY
        (
            SELECT
                Unit,
                RecentCost,
                P1,
                ItemUnitId
            FROM dbo.ItemUnit
            WHERE ItemId = i.ItemId
              AND IsBaseUnit = 1
        ) bu
        LEFT JOIN dbo.Payee p ON p.PayeeId = i.PreferredVendorId
        LEFT JOIN ItemImage im ON i.ItemId = im.ItemId AND im.IsPrimary = 1
        LEFT JOIN View_Category v ON v.CategoryId = i.CategoryId
        LEFT JOIN ItemStorage s ON s.StorageId = i.StorageId
        WHERE ItemType IN (''Inventory'', ''NonInventory'') ';

    -- Filters
    IF @Id IS NOT NULL
        SET @Qry += ' AND i.ItemId = ' + CONVERT(VARCHAR, @Id);
    ELSE
    BEGIN
        -- ------------------------------------------------------------------
        -- Visibility scope (replaces the old @Visibility 4-way branch).
        --
        -- Two ambient bits map straight to the I/D checkboxes on the page:
        --
        --   @ShowInactive @ShowDeleted   rows returned
        --   ------------- -------------  ----------------------------------
        --        0             0         active only (Inactive=0 AND IsDeleted=0)
        --        1             0         active + inactive (IsDeleted=0)
        --        0             1         active + deleted (Inactive=0)
        --        1             1         everything (no scope filter)
        --
        -- The two filters are independent: each only adds its predicate
        -- when its flag is 0 (i.e. "exclude this kind"). When both flags
        -- are 1, neither predicate is added and we get every item row.
        --
        -- Previous 4-way branch on @Visibility:
        --     ELSE IF @Visibility = 'deleted'
        --         SET @Qry += ' AND i.IsDeleted = 1';
        --     ELSE IF @Visibility = 'inactive'
        --         SET @Qry += ' AND i.IsDeleted = 0 AND i.Inactive = 1';
        --     ELSE IF @Visibility = 'active'
        --         SET @Qry += ' AND i.IsDeleted = 0 AND i.Inactive = 0';
        --     ELSE
        --         SET @Qry += ' AND i.IsDeleted = 0';
        -- ------------------------------------------------------------------
        IF @ShowInactive = 0 SET @Qry += ' AND i.Inactive  = 0';
        IF @ShowDeleted  = 0 SET @Qry += ' AND i.IsDeleted = 0';
    END;

    IF @Search IS NOT NULL
    BEGIN
        SET @Search = REPLACE(@Search, '''', '''''');
        SET @Qry += '
            AND (
                ItemCode = ''' + @Search + '''
                OR ItemName LIKE ''%' + @Search + '%''
            )';
    END;

    IF @VendorId IS NOT NULL
        SET @Qry += '
            AND i.ItemId IN (
                SELECT pd.ItemId
                FROM Purchase p
                INNER JOIN PurchaseDetail pd ON p.PurchaseId = pd.PurchaseId
                WHERE p.ArrivalDate >= ''' + CONVERT(VARCHAR, @2year, 101) + '''
                  AND p.PayeeId = ' + CONVERT(VARCHAR, @VendorId) + '
            )';

    IF @StartDate IS NOT NULL
        SET @Qry += '
            AND i.ItemId IN (
                SELECT pd.ItemId
                FROM Purchase p
                INNER JOIN PurchaseDetail pd ON p.PurchaseId = pd.PurchaseId
                WHERE p.ArrivalDate >= ''' + CONVERT(VARCHAR, @StartDate) + '''
                  AND p.ArrivalDate <= ''' + CONVERT(VARCHAR, @EndDate) + '''
            )';

    IF @Container IS NOT NULL
        SET @Qry += '
            AND i.ItemId IN (
                SELECT pd.ItemId
                FROM Purchase p
                INNER JOIN PurchaseDetail pd ON p.PurchaseId = pd.PurchaseId
                WHERE p.ContainerNumber = ''' + @Container + '''
            )';

    IF @CategoryId IS NOT NULL
    BEGIN
        DECLARE @CatIds NVARCHAR(MAX);

        ;WITH CatTree AS
        (
            SELECT CategoryId FROM ItemCategory WHERE CategoryId = @CategoryId
            UNION ALL
            SELECT c.CategoryId
            FROM ItemCategory c
            INNER JOIN CatTree ct ON c.ParentId = ct.CategoryId
        )
        SELECT @CatIds = STRING_AGG(CONVERT(VARCHAR, CategoryId), ',') FROM CatTree;

        SET @Qry += ' AND i.CategoryId IN (' + @CatIds + ')';
    END;

    IF @FilterBy = 'negonhand'
        SET @Qry += ' AND LCloseQty < 0';

    IF @FilterBy = 'instock'
        SET @Qry += ' AND LCloseQty > 0';

    -- Count
    IF @IsCount = 1
    BEGIN
        EXEC sp_executesql @Qry, N'@RCount INT OUTPUT', @RCount = @TotalCount OUTPUT;
        RETURN;
    END;

    -- Sorting
    IF @SortField IS NOT NULL
    BEGIN
        IF @SortField = 'cat'
            SET @Qry += ' ORDER BY v.RootNode, ItemName';
        ELSE IF @SortField = 'storage'
            SET @Qry += ' ORDER BY s.DisplayName, ItemName';
        ELSE IF @SortField = 'exp'
            SET @Qry += ' ORDER BY ExpiryDate';
        ELSE
            SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder;
    END
    ELSE
        SET @Qry += ' ORDER BY i.Last3M DESC, ItemName';

    -- Pagination
    SET @Qry += '
        OFFSET ' + CONVERT(VARCHAR, (@PageSize * (@Pageno - 1))) + ' ROWS
        FETCH NEXT ' + CONVERT(VARCHAR, @Pagesize) + ' ROWS ONLY';

    INSERT INTO #itmtbl
    EXEC (@Qry);

    -- Post processing updates
    ;WITH FutureSales AS
    (
        SELECT sd.ItemId, SUM(sd.BaseShipQty) AS Qty
        FROM Sales s
        INNER JOIN SalesDetail sd ON s.SalesId = sd.SalesId
        WHERE s.ShipDate > CONVERT(DATE, GETDATE())
        GROUP BY sd.ItemId
    )
    UPDATE m
    SET m.FutureQty = fs.Qty * -1
    FROM #itmtbl m
    INNER JOIN FutureSales fs ON m.ItemId = fs.ItemId;

    UPDATE #itmtbl
    SET OnHandQty = LCloseQty - ISNULL(FutureQty, 0);

    UPDATE m
    SET
        m.LastCostDate = r1.ArrivalDate,
        m.BaseRecentCost = r1.TotalCost
    FROM #itmtbl m
    LEFT JOIN View_RecentCost r1 ON r1.ItemId = m.ItemId AND r1.RN = 1;

    ;WITH IncomingPurchase AS
    (
        SELECT pd.ItemId, SUM(pd.OrdQty0) AS Qty
        FROM PurchaseDetail pd
        WHERE pd.ReceiveQty IS NULL
          AND pd.ItemId IS NOT NULL
        GROUP BY pd.ItemId
    )
    UPDATE m
    SET m.UpcomingQty = ip.Qty
    FROM #itmtbl m
    INNER JOIN IncomingPurchase ip ON m.ItemId = ip.ItemId;

    ;WITH LastAdjDate AS
    (
        SELECT ad.ItemId, MAX(a.AdjDate) AS LastAdjDate
        FROM InventoryAdj a
        INNER JOIN InventoryAdjDetail ad ON a.AdjId = ad.AdjId
        INNER JOIN #itmtbl m ON m.ItemId = ad.ItemId
        GROUP BY ad.ItemId
    )
    UPDATE m
    SET m.LastAdjDate = l.LastAdjDate
    FROM #itmtbl m
    INNER JOIN LastAdjDate l ON m.ItemId = l.ItemId;

    -- Final output
    IF @SortField IS NOT NULL
    BEGIN
        IF @SortField IN ('cat', 'storage')
            SELECT * FROM #itmtbl ORDER BY Id;
        ELSE IF @SortField = 'exp'
            SELECT * FROM #itmtbl ORDER BY ExpiryDate;
        ELSE
        BEGIN
            DECLARE @FinalQry NVARCHAR(MAX) =
                'SELECT * FROM #itmtbl ORDER BY ' + @SortField + ' ' + ISNULL(@SortOrder, 'ASC');
            EXEC(@FinalQry);
        END
    END
    ELSE
        SELECT * FROM #itmtbl ORDER BY Last3M DESC, ItemName;

    DROP TABLE #itmtbl;
END
GO
