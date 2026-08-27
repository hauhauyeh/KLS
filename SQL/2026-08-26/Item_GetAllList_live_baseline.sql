CREATE   PROCEDURE [dbo].[Item_GetAllList] -- DECLARE @TotalCount INT; EXEC dbo.Item_GetAllList @Pageno=1,@Pagesize=50,@Search=N'1500''',@StartDate=NULL,@EndDate=NULL,@VendorId=NULL,@Container=NULL,@CategoryId=NULL,@Filterby=NULL,@Id=NULL,@SortField=NULL,@SortOrder=NULL,@IsCount=0,@TotalCount=@TotalCount OUTPUT,@ShowInactive=0,@ShowNonInventory=0
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
    @ShowInactive  BIT = 0,
    @ShowNonInventory BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);
    DECLARE @2year DATE = DATEADD(YEAR, -2, GETDATE());
    DECLARE @SearchTerm NVARCHAR(200) = NULLIF(LTRIM(RTRIM(@Search)), N'');
    DECLARE @SearchLike NVARCHAR(402) = CASE WHEN @SearchTerm IS NULL THEN NULL ELSE N'%' + @SearchTerm + N'%' END;
    DECLARE @SearchPrefix NVARCHAR(201) = CASE WHEN @SearchTerm IS NULL THEN NULL ELSE @SearchTerm + N'%' END;
    DECLARE @SearchItemId INT = CASE
        WHEN @SearchTerm LIKE N'#%' THEN TRY_CAST(NULLIF(LTRIM(RTRIM(SUBSTRING(@SearchTerm, 2, 200))), N'') AS INT)
        ELSE NULL
    END;

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
                    WHEN im.ImageId IS NOT NULL AND im.HasNoBg300 = 1
                        THEN ''/Images/items/'' + CAST(im.ItemId AS VARCHAR(10)) + ''/'' + CAST(im.ImageIndex AS VARCHAR(10)) + ''-300-nobg.png''
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
        WHERE i.ItemType IN (''Inventory'', ''NonInventory'')
          AND i.IsDeleted = 0
          AND (@Id IS NOT NULL OR @SearchTerm IS NOT NULL OR @ShowNonInventory = 1 OR i.ItemType = ''Inventory'') ';

    -- Filters
    IF @Id IS NOT NULL
        SET @Qry += ' AND i.ItemId = @Id';
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
        IF @ShowInactive = 0 AND @SearchTerm IS NULL SET @Qry += ' AND i.Inactive = 0';
    END;

    DECLARE @CodeMatchRank NVARCHAR(MAX) = '';
    DECLARE @FinalPinnedRank NVARCHAR(100) = '';

    IF @SearchTerm IS NOT NULL
    BEGIN
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
        -- 2026-08-12: Product List search is now a broad, parameterized search
        -- over code/name/name2/search tag/barcode/#ItemId. Search mode also
        -- intentionally includes inactive and NonInventory rows while keeping
        -- deleted rows hidden.
        SET @Qry += '
            AND (
                (@SearchItemId IS NOT NULL AND i.ItemId = @SearchItemId)
                OR (
                    @SearchItemId IS NULL
                    AND (
                        i.ItemCode LIKE @SearchLike
                        OR i.ItemName LIKE @SearchLike
                        OR ISNULL(i.ItemName2, '''') LIKE @SearchLike
                        OR ISNULL(i.ItemSearchTag, '''') LIKE @SearchLike
                        OR EXISTS (
                            SELECT 1
                            FROM dbo.ItemUnit iuSearch
                            WHERE iuSearch.ItemId = i.ItemId
                              AND ISNULL(iuSearch.Barcode, '''') LIKE @SearchLike
                        )
                    )
                )
            )';

        SET @CodeMatchRank = '
                CASE
                    WHEN @SearchItemId IS NOT NULL AND i.ItemId = @SearchItemId THEN 0
                    WHEN i.ItemCode = @SearchTerm THEN 1
                    WHEN i.ItemCode LIKE @SearchPrefix THEN 2
                    WHEN i.ItemCode LIKE @SearchLike THEN 3
                    WHEN i.ItemName LIKE @SearchLike THEN 4
                    WHEN ISNULL(i.ItemName2, '''') LIKE @SearchLike THEN 5
                    WHEN ISNULL(i.ItemSearchTag, '''') LIKE @SearchLike THEN 6
                    WHEN EXISTS (
                        SELECT 1
                        FROM dbo.ItemUnit iuRankExact
                        WHERE iuRankExact.ItemId = i.ItemId
                          AND ISNULL(iuRankExact.Barcode, '''') = @SearchTerm
                    ) THEN 7
                    WHEN EXISTS (
                        SELECT 1
                        FROM dbo.ItemUnit iuRank
                        WHERE iuRank.ItemId = i.ItemId
                          AND ISNULL(iuRank.Barcode, '''') LIKE @SearchLike
                    ) THEN 8
                    ELSE 99
                END,
                CASE
                    WHEN i.ItemCode = @SearchTerm THEN 0
                    WHEN i.ItemCode LIKE @SearchPrefix THEN 0
                    WHEN i.ItemCode LIKE @SearchLike THEN CHARINDEX(@SearchTerm, i.ItemCode)
                    WHEN i.ItemName LIKE @SearchLike THEN CHARINDEX(@SearchTerm, i.ItemName)
                    WHEN ISNULL(i.ItemName2, '''') LIKE @SearchLike THEN CHARINDEX(@SearchTerm, ISNULL(i.ItemName2, ''''))
                    WHEN ISNULL(i.ItemSearchTag, '''') LIKE @SearchLike THEN CHARINDEX(@SearchTerm, ISNULL(i.ItemSearchTag, ''''))
                    ELSE 999
                END, ';
        SET @FinalPinnedRank = 'CASE WHEN Id = 1 THEN 0 ELSE 1 END, ';
    END;

    IF @VendorId IS NOT NULL
        SET @Qry += '
            AND i.ItemId IN (
                SELECT pd.ItemId
                FROM Purchase p
                INNER JOIN PurchaseDetail pd ON p.PurchaseId = pd.PurchaseId
                WHERE p.ArrivalDate >= @TwoYear
                  AND p.PayeeId = @VendorId
            )';

    IF @StartDate IS NOT NULL
        SET @Qry += '
            AND i.ItemId IN (
                SELECT pd.ItemId
                FROM Purchase p
                INNER JOIN PurchaseDetail pd ON p.PurchaseId = pd.PurchaseId
                WHERE p.ArrivalDate >= @StartDate
                  AND p.ArrivalDate <= @EndDate
            )';

    IF @Container IS NOT NULL
        SET @Qry += '
            AND i.ItemId IN (
                SELECT pd.ItemId
                FROM Purchase p
                INNER JOIN PurchaseDetail pd ON p.PurchaseId = pd.PurchaseId
                WHERE p.ContainerNumber = @Container
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
        EXEC sp_executesql @Qry,
            N'@RCount INT OUTPUT, @Id INT, @SearchTerm NVARCHAR(200), @SearchLike NVARCHAR(402), @SearchPrefix NVARCHAR(201), @SearchItemId INT, @ShowNonInventory BIT, @VendorId INT, @TwoYear DATE, @StartDate DATE, @EndDate DATE, @Container NVARCHAR(50)',
            @RCount = @TotalCount OUTPUT,
            @Id = @Id,
            @SearchTerm = @SearchTerm,
            @SearchLike = @SearchLike,
            @SearchPrefix = @SearchPrefix,
            @SearchItemId = @SearchItemId,
            @ShowNonInventory = @ShowNonInventory,
            @VendorId = @VendorId,
            @TwoYear = @2year,
            @StartDate = @StartDate,
            @EndDate = @EndDate,
            @Container = @Container;
        RETURN;
    END;

    -- Sorting
    DECLARE @SafeSortField NVARCHAR(50) = NULL;
    DECLARE @SafeSortOrder NVARCHAR(4) =
        CASE WHEN UPPER(ISNULL(@SortOrder, 'ASC')) = 'DESC' THEN 'DESC' ELSE 'ASC' END;

    IF @SortField IN ('recent', 'inventory', 'cat', 'storage', 'exp', 'ItemCode', 'ItemName', 'LastAdjDate', 'BaseRecentCost')
        SET @SafeSortField = @SortField;

    IF @SafeSortField IS NOT NULL
    BEGIN
        IF @SafeSortField = 'cat'
            -- Old: SET @Qry += ' ORDER BY v.RootNode, ItemName';
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + 'v.RootNode, ItemName';
        ELSE IF @SafeSortField = 'storage'
            -- Old: SET @Qry += ' ORDER BY s.DisplayName, ItemName';
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + 's.DisplayName, ItemName';
        ELSE IF @SafeSortField = 'exp'
            -- Old: SET @Qry += ' ORDER BY ExpiryDate';
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + 'ExpiryDate ' + @SafeSortOrder + ', i.ItemName';
        ELSE IF @SafeSortField = 'recent'
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + 'i.CreatedAt DESC, i.ItemId DESC, i.ItemName';
        ELSE IF @SafeSortField = 'inventory'
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + 'ISNULL(i.LCloseQty, 0) + ISNULL((SELECT SUM(sd.BaseShipQty) FROM dbo.Sales s INNER JOIN dbo.SalesDetail sd ON s.SalesId = sd.SalesId WHERE s.ShipDate > CONVERT(DATE, GETDATE()) AND sd.ItemId = i.ItemId), 0) DESC, i.ItemName';
        ELSE IF @SafeSortField = 'ItemCode'
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + 'i.ItemCode ' + @SafeSortOrder + ', i.ItemName';
        ELSE IF @SafeSortField = 'ItemName'
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + 'i.ItemName ' + @SafeSortOrder + ', i.ItemCode';
        ELSE IF @SafeSortField = 'BaseRecentCost'
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + 'bu.RecentCost ' + @SafeSortOrder + ', i.ItemName';
        ELSE IF @SafeSortField = 'LastAdjDate'
            SET @Qry += ' ORDER BY ' + @CodeMatchRank + '(SELECT MAX(a.AdjDate) FROM dbo.InventoryAdj a INNER JOIN dbo.InventoryAdjDetail ad ON a.AdjId = ad.AdjId WHERE ad.ItemId = i.ItemId) ' + @SafeSortOrder + ', i.ItemName';
    END
    ELSE
        -- Old: SET @Qry += ' ORDER BY i.Last3M DESC, ItemName';
        -- Old direct-sort fallback: SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder;
        SET @Qry += ' ORDER BY ' + @CodeMatchRank + 'i.Last3M DESC, ItemName';

    -- Pagination
    SET @Qry += '
        OFFSET ' + CONVERT(VARCHAR, (@PageSize * (@Pageno - 1))) + ' ROWS
        FETCH NEXT ' + CONVERT(VARCHAR, @Pagesize) + ' ROWS ONLY';

    INSERT INTO #itmtbl
    EXEC sp_executesql @Qry,
        N'@Id INT, @SearchTerm NVARCHAR(200), @SearchLike NVARCHAR(402), @SearchPrefix NVARCHAR(201), @SearchItemId INT, @ShowNonInventory BIT, @VendorId INT, @TwoYear DATE, @StartDate DATE, @EndDate DATE, @Container NVARCHAR(50)',
        @Id = @Id,
        @SearchTerm = @SearchTerm,
        @SearchLike = @SearchLike,
        @SearchPrefix = @SearchPrefix,
        @SearchItemId = @SearchItemId,
        @ShowNonInventory = @ShowNonInventory,
        @VendorId = @VendorId,
        @TwoYear = @2year,
        @StartDate = @StartDate,
        @EndDate = @EndDate,
        @Container = @Container;

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
    IF @SafeSortField IS NOT NULL
    BEGIN
        IF @SafeSortField IN ('recent', 'cat', 'storage')
            -- Old: SELECT * FROM #itmtbl ORDER BY Id;
            SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @FinalPinnedRank + 'Id';
        ELSE IF @SafeSortField = 'inventory'
            SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @FinalPinnedRank + 'OnHandQty DESC, ItemName';
        ELSE IF @SafeSortField = 'exp'
            -- Old: SELECT * FROM #itmtbl ORDER BY ExpiryDate;
            SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @FinalPinnedRank + 'ExpiryDate ' + @SafeSortOrder + ', ItemName';
        ELSE IF @SafeSortField = 'ItemCode'
            SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @FinalPinnedRank + 'ItemCode ' + @SafeSortOrder + ', ItemName';
        ELSE IF @SafeSortField = 'ItemName'
            SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @FinalPinnedRank + 'ItemName ' + @SafeSortOrder + ', ItemCode';
        ELSE IF @SafeSortField = 'BaseRecentCost'
            SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @FinalPinnedRank + 'BaseRecentCost ' + @SafeSortOrder + ', ItemName';
        ELSE IF @SafeSortField = 'LastAdjDate'
            SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @FinalPinnedRank + 'LastAdjDate ' + @SafeSortOrder + ', ItemName';

        EXEC(@FinalQry);
    END
    ELSE
    BEGIN
        -- Old: SELECT * FROM #itmtbl ORDER BY Last3M DESC, ItemName;
        -- Old direct-sort fallback: SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @SortField + ' ' + ISNULL(@SortOrder, 'ASC');
        SET @FinalQry = 'SELECT * FROM #itmtbl ORDER BY ' + @FinalPinnedRank + 'Last3M DESC, ItemName';
        EXEC(@FinalQry);
    END;

    DROP TABLE #itmtbl;
END

