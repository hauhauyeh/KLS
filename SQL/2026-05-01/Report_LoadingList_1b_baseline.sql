CREATE OR ALTER PROCEDURE [dbo].[Report_LoadingList]
    @ShipDate DATE,
    @ShipRoute NVARCHAR(50),
    @IsLoad BIT
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #MyPacking
    (
        AutoId INT IDENTITY(1,1),
        Department NVARCHAR(100),
        DepartmentOrder INT,
        StorageSortOrder INT NULL,
        StorageName NVARCHAR(255),
        ItemId INT,
        SalesId INT NULL,
        ItemCode NVARCHAR(50),
        ItemName NVARCHAR(255),
        Comment NVARCHAR(255),
        ShipQty DECIMAL(18,2),
        Unit NVARCHAR(50),
        ShipRoute NVARCHAR(50),
        LoadRoute NVARCHAR(50),
        LoadRouteSortGroup INT,
        LoadRouteSortOrder INT NULL
    );

    -- Section: Cooler cs rows
    -- Combine rows when ItemId, Unit, Comment, ShipRoute, and effective load
    -- route land in the same bucket.
    INSERT INTO #MyPacking
    (
        Department,
        DepartmentOrder,
        StorageSortOrder,
        StorageName,
        ItemId,
        SalesId,
        ItemCode,
        ItemName,
        Comment,
        ShipQty,
        Unit,
        ShipRoute,
        LoadRoute,
        LoadRouteSortGroup,
        LoadRouteSortOrder
    )
    SELECT
        'Cooler',
        1,
        st.SortOrder,
        st.Section,
        sd.ItemId,
        NULL,
        MIN(i.ItemCode),
        MIN(i.ItemName),
        sd.Notes,
        SUM(sd.ShipQty),
        sd.Unit,
        s.ShipRoute,
        -- 2026-05-02 00:08 ET: legacy scalar function call commented out while
        -- replacing Report_LoadingList with inline load-route logic.
        -- dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL
                THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
            ELSE s.ShipRoute
        END,
        MAX(CASE
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL THEN 1
            ELSE 0
        END),
        MAX(CASE
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 THEN s.RouteOrder
            ELSE NULL
        END)
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    INNER JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    WHERE s.ShipDate = @ShipDate
      AND sd.ShipQty > 0
      AND st.Zone = 'Cooler'
      AND ISNULL(LOWER(sd.Unit), '') = 'cs'
      AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
    GROUP BY
        st.SortOrder,
        st.Section,
        sd.ItemId,
        sd.Notes,
        sd.Unit,
        s.ShipRoute,
        -- 2026-05-02 00:08 ET: legacy scalar function call commented out while
        -- replacing Report_LoadingList with inline load-route logic.
        -- dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL
                THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
            ELSE s.ShipRoute
        END;

    -- Section: Cooler lbs rows
    -- Keep rows split by SalesId even when the item, unit, and comment match.
    INSERT INTO #MyPacking
    (
        Department,
        DepartmentOrder,
        StorageSortOrder,
        StorageName,
        ItemId,
        SalesId,
        ItemCode,
        ItemName,
        Comment,
        ShipQty,
        Unit,
        ShipRoute,
        LoadRoute,
        LoadRouteSortGroup,
        LoadRouteSortOrder
    )
    SELECT
        'Cooler',
        1,
        st.SortOrder,
        st.Section,
        sd.ItemId,
        s.SalesId,
        MIN(i.ItemCode),
        MIN(i.ItemName),
        sd.Notes,
        SUM(sd.ShipQty),
        sd.Unit,
        s.ShipRoute,
        -- 2026-05-02 00:08 ET: legacy scalar function call commented out while
        -- replacing Report_LoadingList with inline load-route logic.
        -- dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL
                THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
            ELSE s.ShipRoute
        END,
        MAX(CASE
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL THEN 1
            ELSE 0
        END),
        MAX(CASE
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 THEN s.RouteOrder
            ELSE NULL
        END)
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    INNER JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    WHERE s.ShipDate = @ShipDate
      AND sd.ShipQty > 0
      AND st.Zone = 'Cooler'
      AND ISNULL(LOWER(sd.Unit), '') = 'lbs'
      AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
    GROUP BY
        st.SortOrder,
        st.Section,
        sd.ItemId,
        s.SalesId,
        sd.Notes,
        sd.Unit,
        s.ShipRoute,
        -- 2026-05-02 00:08 ET: legacy scalar function call commented out while
        -- replacing Report_LoadingList with inline load-route logic.
        -- dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL
                THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
            ELSE s.ShipRoute
        END;

    -- Section: Freezer rows
    INSERT INTO #MyPacking
    (
        Department,
        DepartmentOrder,
        StorageSortOrder,
        StorageName,
        ItemId,
        SalesId,
        ItemCode,
        ItemName,
        Comment,
        ShipQty,
        Unit,
        ShipRoute,
        LoadRoute,
        LoadRouteSortGroup,
        LoadRouteSortOrder
    )
    SELECT
        'Freezer',
        2,
        st.SortOrder,
        st.Section,
        sd.ItemId,
        NULL,
        MIN(i.ItemCode),
        MIN(i.ItemName),
        sd.Notes,
        SUM(sd.ShipQty),
        sd.Unit,
        s.ShipRoute,
        -- 2026-05-02 00:08 ET: legacy scalar function call commented out while
        -- replacing Report_LoadingList with inline load-route logic.
        -- dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL
                THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
            ELSE s.ShipRoute
        END,
        MAX(CASE
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL THEN 1
            ELSE 0
        END),
        MAX(CASE
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 THEN s.RouteOrder
            ELSE NULL
        END)
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    INNER JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    WHERE s.ShipDate = @ShipDate
      AND sd.ShipQty > 0
      AND st.Zone = 'Freezer'
      AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
    GROUP BY
        st.SortOrder,
        st.Section,
        sd.ItemId,
        sd.Notes,
        sd.Unit,
        s.ShipRoute,
        -- 2026-05-02 00:08 ET: legacy scalar function call commented out while
        -- replacing Report_LoadingList with inline load-route logic.
        -- dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL
                THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
            ELSE s.ShipRoute
        END;

    -- Section: Driver rows
    INSERT INTO #MyPacking
    (
        Department,
        DepartmentOrder,
        StorageSortOrder,
        StorageName,
        ItemId,
        SalesId,
        ItemCode,
        ItemName,
        Comment,
        ShipQty,
        Unit,
        ShipRoute,
        LoadRoute,
        LoadRouteSortGroup,
        LoadRouteSortOrder
    )
    SELECT
        'Driver',
        3,
        st.SortOrder,
        st.Section,
        sd.ItemId,
        NULL,
        MIN(i.ItemCode),
        MIN(i.ItemName),
        sd.Notes,
        SUM(sd.ShipQty),
        sd.Unit,
        s.ShipRoute,
        -- 2026-05-02 00:08 ET: legacy scalar function call commented out while
        -- replacing Report_LoadingList with inline load-route logic.
        -- dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL
                THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
            ELSE s.ShipRoute
        END,
        MAX(CASE
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL THEN 1
            ELSE 0
        END),
        MAX(CASE
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 THEN s.RouteOrder
            ELSE NULL
        END)
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    INNER JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    WHERE s.ShipDate = @ShipDate
      AND sd.ShipQty > 0
      AND st.Zone = 'Driver'
      AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
    GROUP BY
        st.SortOrder,
        st.Section,
        sd.ItemId,
        sd.Notes,
        sd.Unit,
        s.ShipRoute,
        -- 2026-05-02 00:08 ET: legacy scalar function call commented out while
        -- replacing Report_LoadingList with inline load-route logic.
        -- dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL
                THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
            ELSE s.ShipRoute
        END;

    -- Section: Warehouse rows
    INSERT INTO #MyPacking
    (
        Department,
        DepartmentOrder,
        StorageSortOrder,
        StorageName,
        ItemId,
        SalesId,
        ItemCode,
        ItemName,
        Comment,
        ShipQty,
        Unit,
        ShipRoute,
        LoadRoute,
        LoadRouteSortGroup,
        LoadRouteSortOrder
    )
    SELECT
        'Warehouse',
        4,
        st.SortOrder,
        st.Section,
        sd.ItemId,
        NULL,
        MIN(i.ItemCode),
        MIN(i.ItemName),
        sd.Notes,
        SUM(sd.ShipQty),
        sd.Unit,
        s.ShipRoute,
        -- 2026-05-02 00:08 ET: legacy scalar function call commented out while
        -- replacing Report_LoadingList with inline load-route logic.
        -- dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL
                THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
            ELSE s.ShipRoute
        END,
        MAX(CASE
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL THEN 1
            ELSE 0
        END),
        MAX(CASE
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 THEN s.RouteOrder
            ELSE NULL
        END)
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    INNER JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    WHERE s.ShipDate = @ShipDate
      AND sd.ShipQty > 0
      AND st.Zone = 'Warehouse'
      AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
    GROUP BY
        st.SortOrder,
        st.Section,
        sd.ItemId,
        sd.Notes,
        sd.Unit,
        s.ShipRoute,
        -- 2026-05-02 00:08 ET: legacy scalar function call commented out while
        -- replacing Report_LoadingList with inline load-route logic.
        -- dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL
                THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
            ELSE s.ShipRoute
        END;

    -- Section: Final report output
    -- Keep the same visible output shape while switching the internal route
    -- ordering away from parsed LoadRoute string logic and onto base route
    -- columns carried in #MyPacking.
    SELECT
        m.AutoId,
        m.Department,
        m.DepartmentOrder,
        m.StorageName,
        m.ItemCode,
        m.ItemName,
        m.Comment,
        m.ShipQty,
        m.Unit,
        m.ShipRoute,
        m.LoadRoute,
        i.ItemBoxDesc
    FROM #MyPacking AS m
    INNER JOIN Item AS i ON m.ItemId = i.ItemId
    ORDER BY
        -- 2026-05-02 00:25 ET: legacy parsed LoadRoute sort commented out after
        -- carrying aggregated base-route sort helpers into #MyPacking for direct
        -- ordering without widening the original grouping.
        -- CASE
        --     WHEN m.LoadRoute = m.ShipRoute THEN 0
        --     ELSE 1
        -- END,
        -- TRY_CAST(REPLACE(m.LoadRoute, m.ShipRoute, '') AS INT) DESC,
        m.LoadRouteSortGroup,
        ISNULL(m.LoadRouteSortOrder, 0) DESC,
        m.DepartmentOrder,
        ISNULL(m.StorageSortOrder, 2147483647),
        m.StorageName,
        m.ItemName;

    DROP TABLE #MyPacking;
END
