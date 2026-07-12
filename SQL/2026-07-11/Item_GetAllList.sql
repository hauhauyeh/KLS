SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[Item_GetAllList]
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
        -- 2026-06-25: recent-cost breakdown (goods + landing per case), filled by the same
        -- View_RecentCost pivot below. Invariant: BaseRecentCost = BaseGoodsCost + BaseLandingCost.
        BaseGoodsCost DECIMAL(18,2),
        BaseLandingCost DECIMAL(18,2),
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
                -- 2026-06-25: NULL placeholders for the cost breakdown; filled by the pivot
                -- UPDATE below. Position MUST match #itmtbl (INSERT ... EXEC(@Qry) is positional).
                NULL AS BaseGoodsCost,
                NULL AS BaseLandingCost,
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

    DECLARE @CodeMatchRank NVARCHAR(MAX) = '';
    DECLARE @FinalPinnedRank NVARCHAR(100) = '';

    IF @Search IS NOT NULL
    BEGIN
        SET @Search = REPLACE(@Search, '''', '''''');
        -- Old:
        -- SET @Qry += '
        --     AND (
        --         ItemCode = ''' + @Search + '''
        --         OR ItemName LIKE ''%' + @Search + '%''
        --     )';
        -- 2026-07-11: search results are normal ItemName rows plus one reserved
        -- best ItemCode candidate (exact, prefix, contains). This keeps code
        -- search from flooding the result set while still giving code users a
        -- top-slot match.
        SET @Qry += '
            AND (
                ItemName LIKE ''%' + @Search + '%''
                OR i.ItemId = (
                    SELECT TOP (1) ci.ItemId
                    FROM dbo.Item ci
                    WHERE ci.ItemType IN (''Inventory'', ''NonInventory'')
                      AND ci.IsDeleted = 0
                      ' + CASE WHEN @ShowInactive = 0 THEN 'AND ci.Inactive = 0' ELSE '' END + '
                      AND ci.ItemCode LIKE ''%' + @Search + '%''
                    ORDER BY
                        CASE
                            WHEN ci.ItemCode = ''' + @Search + ''' THEN 0
                            WHEN ci.ItemCode LIKE ''' + @Search + '%'' THEN 1
                            ELSE 2
                        END,
                        LEN(ci.ItemCode),
                        ci.ItemCode,
                        ci.ItemName
                )
            )';

        SET @CodeMatchRank = '
                CASE WHEN i.ItemId = (
                    SELECT TOP (1) ci.ItemId
                    FROM dbo.Item ci
                    WHERE ci.ItemType IN (''Inventory'', ''NonInventory'')
                      AND ci.IsDeleted = 0
                      ' + CASE WHEN @ShowInactive = 0 THEN 'AND ci.Inactive = 0' ELSE '' END + '
                      AND ci.ItemCode LIKE ''%' + @Search + '%''
                    ORDER BY
                        CASE
                            WHEN ci.ItemCode = ''' + @Search + ''' THEN 0
                            WHEN ci.ItemCode LIKE ''' + @Search + '%'' THEN 1
                            ELSE 2
                        END,
                        LEN(ci.ItemCode),
                        ci.ItemCode,
                        ci.ItemName
                ) THEN 0 ELSE 1 END, ';
        SET @FinalPinnedRank = 'CASE WHEN Id = 1 THEN 0 ELSE 1 END, ';
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
            -- Old: SET @Qry += ' ORDER BY v.RootNode, ItemName';
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + 'v.RootNode, ItemName';
        ELSE IF @SortField = 'storage'
            -- Old: SET @Qry += ' ORDER BY s.DisplayName, ItemName';
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + 's.DisplayName, ItemName';
        ELSE IF @SortField = 'exp'
            -- Old: SET @Qry += ' ORDER BY ExpiryDate';
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + 'ExpiryDate';
        ELSE
            -- Old: SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder;
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + @SortField + ' ' + @SortOrder;
    END
    ELSE
        -- Old: SET @Qry += ' ORDER BY i.Last3M DESC, ItemName';
        SET @Qry += ' ORDER BY ' + @CodeMatchRank + 'i.Last3M DESC, ItemName';

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
            -- 2026-06-25: split the RN=1 recent cost into goods + landing per case.
            MAX(CASE WHEN RN = 1 THEN BaseCost          END) AS RecentGoods,
            MAX(CASE WHEN RN = 1 THEN LandedCostPerCase END) AS RecentLanding,
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
        -- 2026-06-25: surface the goods/landing split (0 when no landing present).
        m.BaseGoodsCost    = ISNULL(p.RecentGoods, 0),
        m.BaseLandingCost  = ISNULL(p.RecentLanding, 0),
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
    DECLARE @FinalQry NVARCHAR(MAX);
    IF @SortField IS NOT NULL
    BEGIN
        IF @SortField IN ('cat', 'storage')
            -- Old: SELECT * FROM #itmtbl ORDER BY Id;
            SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @FinalPinnedRank + 'Id';
        ELSE IF @SortField = 'exp'
            -- Old: SELECT * FROM #itmtbl ORDER BY ExpiryDate;
            SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @FinalPinnedRank + 'ExpiryDate';
        ELSE
            -- Old: SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @SortField + ' ' + ISNULL(@SortOrder, 'ASC');
            SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @FinalPinnedRank + @SortField + ' ' + ISNULL(@SortOrder, 'ASC');

        EXEC(@FinalQry);
    END
    ELSE
    BEGIN
        -- Old: SELECT * FROM #itmtbl ORDER BY Last3M DESC, ItemName;
        SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @FinalPinnedRank + 'Last3M DESC, ItemName';
        EXEC(@FinalQry);
    END;

    DROP TABLE #itmtbl;
END

