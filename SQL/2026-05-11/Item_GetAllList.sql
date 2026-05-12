-- Item_GetAllList rev 2026-05-11 (cost-trend restore)
-- Restores the cost-trend fields BaseRecentCostB4 and CostIntervalDays
-- that were dropped during the product-list-improve refactor. Reads
-- both RN=1 and RN=2 from View_RecentCost via a pivot CTE (legacy
-- pattern) and computes the day interval inline.
--
-- View_RecentCost is capped at RN<=2 by its definition; the CTE's
-- explicit WHERE RN IN (1, 2) documents intent without changing
-- behavior, and is defensive if the view's cap ever changes.
--
-- TotalCost in View_RecentCost is (BaseCost + LandedCostPerCase),
-- i.e. goods cost plus landing per case. The restored trend reflects
-- movement in the all-in landed cost, not just goods.
--
-- The percent change is NOT computed in SQL; it's derived in the
-- ItemList DTO via BaseCostTrendPercent getter (mirrors BaseP1Percent).
--
-- Prior rev (2026-05-08 -- I-only forward-removal) header preserved:
--   Removes @ShowDeleted parameter and IsDeleted projection. Keeps
--   @ShowInactive (the I toggle on the page list) and unconditionally
--   filters i.IsDeleted = 0. The (@ShowInactive + @ShowDeleted)
--   pair from 2026-05-07 was forward-removed in that round.
--
-- Workflow: 5-step SQL workflow per CLAUDE.md. This file is the
-- workspace-root scratch; baseline is at
-- KLS\SQL\2026-05-11\Item_GetAllList_live_baseline.sql.

-- _prev already exists from prior rounds, so the rename is a no-op here.
-- The guard is kept defensively for safety.
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
    -- Old @ShowDeleted BIT = 0 removed 2026-05-08 (forward-removal of D toggle).
    -- Deleted items are now always hidden via an unconditional WHERE clause
    -- below; no caller flag controls it.
    -- @ShowInactive: when 1, results include rows where Inactive = 1.
    --                Default 0 keeps the page list active-only as before.
    @ShowInactive  BIT = 0
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
        -- 2026-05-11: cost-trend restore. Both filled by the post-process
        -- pivot UPDATE on View_RecentCost (RN=1 vs RN=2).
        BaseRecentCostB4 DECIMAL(18,2),
        CostIntervalDays INT,
        BaseP1 DECIMAL(18,2),
        SaftyInventory DECIMAL(18,2),
        PreferredVendorId INT,
        VendorName NVARCHAR(255),
        IsHighlighted BIT,
        Inactive BIT,
        -- IsDeleted BIT removed 2026-05-08 -- DTO no longer carries it.
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
                -- 2026-05-11: NULL placeholders for the cost-trend columns;
                -- populated by the post-process pivot UPDATE below.
                NULL AS BaseRecentCostB4,
                NULL AS CostIntervalDays,
                bu.P1,
                i.SaftyInventory,
                i.PreferredVendorId,
                p.PayeeName,
                i.IsHighlighted,
                i.Inactive,
                -- i.IsDeleted removed 2026-05-08 -- DTO no longer carries it.
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
        -- Visibility scope (I-only, 2026-05-08).
        --
        -- The D toggle was removed; deleted items are now always hidden
        -- regardless of any flag. Only the I toggle remains.
        --
        --   @ShowInactive    rows returned (deleted always excluded)
        --   -------------    ------------------------------------------
        --        0           active only           (Inactive=0 AND IsDeleted=0)
        --        1           active + inactive     (IsDeleted=0)
        --
        -- Previous (2026-05-07) two-bit branch:
        --     IF @ShowInactive = 0 SET @Qry += ' AND i.Inactive  = 0';
        --     IF @ShowDeleted  = 0 SET @Qry += ' AND i.IsDeleted = 0';
        --
        -- And before that (2026-05-06 baseline) the 4-way @Visibility branch:
        --     ELSE IF @Visibility = 'deleted'
        --         SET @Qry += ' AND i.IsDeleted = 1';
        --     ELSE IF @Visibility = 'inactive'
        --         SET @Qry += ' AND i.IsDeleted = 0 AND i.Inactive = 1';
        --     ELSE IF @Visibility = 'active'
        --         SET @Qry += ' AND i.IsDeleted = 0 AND i.Inactive = 0';
        --     ELSE
        --         SET @Qry += ' AND i.IsDeleted = 0';
        -- ------------------------------------------------------------------
        IF @ShowInactive = 0 SET @Qry += ' AND i.Inactive = 0';
        SET @Qry += ' AND i.IsDeleted = 0';
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

    -- Old (2026-05-11 replaced -- RN=1 only, lost cost trend):
    -- UPDATE m
    -- SET m.LastCostDate = r1.ArrivalDate, m.BaseRecentCost = r1.TotalCost
    -- FROM #itmtbl m
    -- LEFT JOIN View_RecentCost r1 ON r1.ItemId = m.ItemId AND r1.RN = 1;
    --
    -- New: pivot RN=1 vs RN=2 from View_RecentCost. TotalCost in the view
    -- is (BaseCost + LandedCostPerCase) = goods + landing per case, so the
    -- restored trend reflects movement in the all-in landed cost.
    ;WITH PivotedCosts AS (
        SELECT
            ItemId,
            MAX(CASE WHEN RN = 1 THEN TotalCost   END) AS RecentCost,
            MAX(CASE WHEN RN = 2 THEN TotalCost   END) AS RecentCostB4,
            MAX(CASE WHEN RN = 1 THEN ArrivalDate END) AS LastCostDate,
            MAX(CASE WHEN RN = 2 THEN ArrivalDate END) AS PrevCostDate
        FROM dbo.View_RecentCost
        WHERE RN IN (1, 2)
        GROUP BY ItemId
    )
    UPDATE m
    SET
        m.LastCostDate     = p.LastCostDate,
        m.BaseRecentCost   = p.RecentCost,
        m.BaseRecentCostB4 = p.RecentCostB4,
        m.CostIntervalDays = DATEDIFF(DAY, p.PrevCostDate, p.LastCostDate)
    FROM #itmtbl m
    LEFT JOIN PivotedCosts p ON p.ItemId = m.ItemId;

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
