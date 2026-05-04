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

    CREATE TABLE #SourceRows
    (
        SalesId INT,
        ItemId INT,
        ItemCode NVARCHAR(50),
        ItemName NVARCHAR(255),
        Comment NVARCHAR(255),
        ShipQty DECIMAL(18,2),
        Unit NVARCHAR(50),
        ShipRoute NVARCHAR(50),
        LoadRoute NVARCHAR(50),
        LoadRouteSortGroup INT,
        LoadRouteSortOrder INT NULL,
        Zone NVARCHAR(50),
        SortOrder INT,
        Section NVARCHAR(255)
    );

    -- Section: Stage source rows once
    -- Read the common Sales, SalesDetail, Item, and ItemStorage rowset one time,
    -- then let the five loading-list branches aggregate from this shared temp
    -- table instead of repeating the same base-table scan.
    INSERT INTO #SourceRows
    (
        SalesId,
        ItemId,
        ItemCode,
        ItemName,
        Comment,
        ShipQty,
        Unit,
        ShipRoute,
        LoadRoute,
        LoadRouteSortGroup,
        LoadRouteSortOrder,
        Zone,
        SortOrder,
        Section
    )
    SELECT
        s.SalesId,
        sd.ItemId,
        i.ItemCode,
        i.ItemName,
        sd.Notes,
        sd.ShipQty,
        sd.Unit,
        s.ShipRoute,
        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL
                THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
            ELSE s.ShipRoute
        END,
        CASE
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND s.RouteOrder IS NOT NULL THEN 1
            ELSE 0
        END,
        CASE
            WHEN ISNULL(s.IsLoadSeparate, 0) = 1 THEN s.RouteOrder
            ELSE NULL
        END,
        st.Zone,
        st.SortOrder,
        st.Section
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    INNER JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    WHERE s.ShipDate = @ShipDate
      AND sd.ShipQty > 0
      AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END;

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
        src.SortOrder,
        src.Section,
        src.ItemId,
        NULL,
        MIN(src.ItemCode),
        MIN(src.ItemName),
        src.Comment,
        SUM(src.ShipQty),
        src.Unit,
        src.ShipRoute,
        src.LoadRoute,
        MAX(src.LoadRouteSortGroup),
        MAX(src.LoadRouteSortOrder)
    -- 2026-05-02 01:05 ET: legacy base-table scan commented out after staging
    -- shared source rows once in #SourceRows for Report_LoadingList 1C1.
    -- FROM Sales AS s
    -- INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    -- INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    -- INNER JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    -- WHERE s.ShipDate = @ShipDate
    --   AND sd.ShipQty > 0
    --   AND st.Zone = 'Cooler'
    --   AND ISNULL(LOWER(sd.Unit), '') = 'cs'
    --   AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
    FROM #SourceRows AS src
    WHERE src.Zone = 'Cooler'
      AND ISNULL(LOWER(src.Unit), '') = 'cs'
    GROUP BY
        src.SortOrder,
        src.Section,
        src.ItemId,
        src.Comment,
        src.Unit,
        src.ShipRoute,
        src.LoadRoute;

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
        src.SortOrder,
        src.Section,
        src.ItemId,
        src.SalesId,
        MIN(src.ItemCode),
        MIN(src.ItemName),
        src.Comment,
        SUM(src.ShipQty),
        src.Unit,
        src.ShipRoute,
        src.LoadRoute,
        MAX(src.LoadRouteSortGroup),
        MAX(src.LoadRouteSortOrder)
    -- 2026-05-02 01:05 ET: legacy base-table scan commented out after staging
    -- shared source rows once in #SourceRows for Report_LoadingList 1C1.
    -- FROM Sales AS s
    -- INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    -- INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    -- INNER JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    -- WHERE s.ShipDate = @ShipDate
    --   AND sd.ShipQty > 0
    --   AND st.Zone = 'Cooler'
    --   AND ISNULL(LOWER(sd.Unit), '') = 'lbs'
    --   AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
    FROM #SourceRows AS src
    WHERE src.Zone = 'Cooler'
      AND ISNULL(LOWER(src.Unit), '') = 'lbs'
    GROUP BY
        src.SortOrder,
        src.Section,
        src.ItemId,
        src.SalesId,
        src.Comment,
        src.Unit,
        src.ShipRoute,
        src.LoadRoute;

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
        src.SortOrder,
        src.Section,
        src.ItemId,
        NULL,
        MIN(src.ItemCode),
        MIN(src.ItemName),
        src.Comment,
        SUM(src.ShipQty),
        src.Unit,
        src.ShipRoute,
        src.LoadRoute,
        MAX(src.LoadRouteSortGroup),
        MAX(src.LoadRouteSortOrder)
    -- 2026-05-02 01:05 ET: legacy base-table scan commented out after staging
    -- shared source rows once in #SourceRows for Report_LoadingList 1C1.
    -- FROM Sales AS s
    -- INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    -- INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    -- INNER JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    -- WHERE s.ShipDate = @ShipDate
    --   AND sd.ShipQty > 0
    --   AND st.Zone = 'Freezer'
    --   AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
    FROM #SourceRows AS src
    WHERE src.Zone = 'Freezer'
    GROUP BY
        src.SortOrder,
        src.Section,
        src.ItemId,
        src.Comment,
        src.Unit,
        src.ShipRoute,
        src.LoadRoute;

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
        src.SortOrder,
        src.Section,
        src.ItemId,
        NULL,
        MIN(src.ItemCode),
        MIN(src.ItemName),
        src.Comment,
        SUM(src.ShipQty),
        src.Unit,
        src.ShipRoute,
        src.LoadRoute,
        MAX(src.LoadRouteSortGroup),
        MAX(src.LoadRouteSortOrder)
    -- 2026-05-02 01:05 ET: legacy base-table scan commented out after staging
    -- shared source rows once in #SourceRows for Report_LoadingList 1C1.
    -- FROM Sales AS s
    -- INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    -- INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    -- INNER JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    -- WHERE s.ShipDate = @ShipDate
    --   AND sd.ShipQty > 0
    --   AND st.Zone = 'Driver'
    --   AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
    FROM #SourceRows AS src
    WHERE src.Zone = 'Driver'
    GROUP BY
        src.SortOrder,
        src.Section,
        src.ItemId,
        src.Comment,
        src.Unit,
        src.ShipRoute,
        src.LoadRoute;

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
        src.SortOrder,
        src.Section,
        src.ItemId,
        NULL,
        MIN(src.ItemCode),
        MIN(src.ItemName),
        src.Comment,
        SUM(src.ShipQty),
        src.Unit,
        src.ShipRoute,
        src.LoadRoute,
        MAX(src.LoadRouteSortGroup),
        MAX(src.LoadRouteSortOrder)
    -- 2026-05-02 01:05 ET: legacy base-table scan commented out after staging
    -- shared source rows once in #SourceRows for Report_LoadingList 1C1.
    -- FROM Sales AS s
    -- INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    -- INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    -- INNER JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    -- WHERE s.ShipDate = @ShipDate
    --   AND sd.ShipQty > 0
    --   AND st.Zone = 'Warehouse'
    --   AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
    FROM #SourceRows AS src
    WHERE src.Zone = 'Warehouse'
    GROUP BY
        src.SortOrder,
        src.Section,
        src.ItemId,
        src.Comment,
        src.Unit,
        src.ShipRoute,
        src.LoadRoute;

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

    DROP TABLE #SourceRows;
    DROP TABLE #MyPacking;
END
