SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

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
        LoadRoute NVARCHAR(50)
    );

    -- Cooler cs rows:
    -- combine when ItemId + Unit + Comment land in the same ShipRoute/LoadRoute bucket.
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
        LoadRoute
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
        dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
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
        dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate);

    -- Cooler lbs rows:
    -- even when ItemId + Unit + Comment match, keep them split by source SalesId.
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
        LoadRoute
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
        dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
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
        dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate);

    -- Freezer rows.
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
        LoadRoute
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
        dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
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
        dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate);

    -- Driver rows.
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
        LoadRoute
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
        dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
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
        dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate);

    -- Warehouse rows.
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
        LoadRoute
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
        dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate)
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
        dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate);

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
        CASE
            WHEN m.LoadRoute = m.ShipRoute THEN 0
            ELSE 1
        END,
        TRY_CAST(REPLACE(m.LoadRoute, m.ShipRoute, '') AS INT) DESC,
        m.DepartmentOrder,
        ISNULL(m.StorageSortOrder, 2147483647),
        m.StorageName,
        m.ItemName;

    DROP TABLE #MyPacking;
END
GO
