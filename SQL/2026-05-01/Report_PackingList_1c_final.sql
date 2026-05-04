SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_PackingList] --[Report_PackingList] '02/05/2026','E',null
    @ShipDate   DATE,
    @ShipRoute  NVARCHAR(50),
    @SalesId    INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);

    CREATE TABLE #SalesRows
    (
        SalesId INT PRIMARY KEY,
        SalesNumber NVARCHAR(50),
        PayeeName NVARCHAR(255),
        ShipRoute NVARCHAR(50),
        RouteOrder INT NULL,
        IsLoadSeparate BIT NULL,
        LoadRoute NVARCHAR(50),
        LoadRouteSortGroup INT,
        LoadRouteSortOrder INT NULL
    );

    CREATE TABLE #SourceRows
    (
        SalesId INT,
        SalesNumber NVARCHAR(50),
        PayeeName NVARCHAR(255),
        StorageId INT NULL,
        StorageZone NVARCHAR(100) NULL,
        ItemId INT,
        ItemName NVARCHAR(255),
        ItemName2 NVARCHAR(255),
        Unit NVARCHAR(100),
        ShipQty DECIMAL(18,2),
        BaseShipQty DECIMAL(18,6),
        Comment NVARCHAR(255),
        FactorToBase DECIMAL(18,6) NULL,
        ShipRoute NVARCHAR(50),
        RouteOrder INT NULL,
        IsLoadSeparate BIT NULL,
        LoadRoute NVARCHAR(50),
        LoadRouteSortGroup INT,
        LoadRouteSortOrder INT NULL
    );

    CREATE TABLE #MyItem
    (
        Id           INT IDENTITY(1,1),
        StorageId    INT,
        StorageName  NVARCHAR(100),
        -- Carry source sale/customer only for non-cs units so TotalSplit can
        -- keep cs as one combined line while still showing customer detail
        -- underneath the secondary unit total.
        SalesNumber  NVARCHAR(50),
        PayeeName    NVARCHAR(255),
        ItemId       INT,
        ItemName     NVARCHAR(255),
        ItemName2    NVARCHAR(255),
        Unit         NVARCHAR(100),
        ShipQty      DECIMAL(18,2),
        BaseShipQty  DECIMAL(18,6),
        Comment      NVARCHAR(255),
        ShipRoute    NVARCHAR(10),
        LoadRoute    NVARCHAR(50),
        LoadRouteSortGroup INT,
        LoadRouteSortOrder INT NULL,
        Sort         INT,
        -- Report-only tie breaker inside one storage group.
        -- Used to push reclassified cooler lbs rows to the end of Cooler.
        TailSort     INT
    );

    -- Section: Stage filtered sales once
    -- Keep sales/customer rows separate from detail rows so customer marker
    -- output remains based on Sales even when detail rows are filtered out.
    INSERT INTO #SalesRows
    (
        SalesId,
        SalesNumber,
        PayeeName,
        ShipRoute,
        RouteOrder,
        IsLoadSeparate,
        LoadRoute,
        LoadRouteSortGroup,
        LoadRouteSortOrder
    )
    SELECT
        s.SalesId,
        s.SalesNumber,
        p.PayeeName,
        s.ShipRoute,
        s.RouteOrder,
        s.IsLoadSeparate,
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
        END
    FROM Sales AS s
    INNER JOIN Payee AS p ON p.PayeeId = s.ShipId
    WHERE s.ShipDate = CASE WHEN @ShipDate IS NOT NULL THEN @ShipDate ELSE s.ShipDate END
      AND s.ShipRoute = CASE WHEN @ShipRoute IS NOT NULL THEN @ShipRoute ELSE s.ShipRoute END
      AND s.SalesId = CASE WHEN @SalesId IS NOT NULL THEN @SalesId ELSE s.SalesId END;

    -- Section: Stage qualifying packing detail rows once
    -- Both item branches use this shared source instead of repeating the same
    -- Sales, SalesDetail, Item, Payee, and ItemStorage joins.
    INSERT INTO #SourceRows
    (
        SalesId,
        SalesNumber,
        PayeeName,
        StorageId,
        StorageZone,
        ItemId,
        ItemName,
        ItemName2,
        Unit,
        ShipQty,
        BaseShipQty,
        Comment,
        FactorToBase,
        ShipRoute,
        RouteOrder,
        IsLoadSeparate,
        LoadRoute,
        LoadRouteSortGroup,
        LoadRouteSortOrder
    )
    SELECT
        sr.SalesId,
        sr.SalesNumber,
        sr.PayeeName,
        i.StorageId,
        st.Zone,
        sd.ItemId,
        i.ItemName,
        i.ItemName2,
        sd.Unit,
        sd.ShipQty,
        sd.BaseShipQty,
        sd.Notes,
        sd.FactorToBase,
        sr.ShipRoute,
        sr.RouteOrder,
        sr.IsLoadSeparate,
        sr.LoadRoute,
        sr.LoadRouteSortGroup,
        sr.LoadRouteSortOrder
    FROM #SalesRows AS sr
    INNER JOIN SalesDetail AS sd ON sd.SalesId = sr.SalesId
    INNER JOIN Item AS i ON i.ItemId = sd.ItemId
    LEFT JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    WHERE sd.ShipQty >= 0;

    /* Base unit items
       Aggregate only within the same sales document. This preserves the old
       base-unit combine behavior per sale, but prevents identical rows from
       different SalesNumber values from collapsing into one packing row. */
    INSERT INTO #MyItem
    (
        StorageId,
        StorageName,
        SalesNumber,
        PayeeName,
        ItemId,
        ItemName,
        ItemName2,
        Unit,
        ShipQty,
        BaseShipQty,
        Comment,
        ShipRoute,
        LoadRoute,
        LoadRouteSortGroup,
        LoadRouteSortOrder,
        Sort,
        TailSort
    )
    SELECT
        src.StorageId,
        -- Zone classification:
        -- 1. Keep the original zone by default.
        -- 2. Original Cooler rows split into:
        --    Cooler  = cs + lbs
        --    Prepack = other units
        CASE
            WHEN src.StorageZone = 'Cooler' AND ISNULL(LOWER(src.Unit), '') NOT IN ('cs', 'lbs') THEN 'Prepack'
            ELSE src.StorageZone
        END,
        -- Only non-cs units need source order/customer carried through.
        CASE WHEN ISNULL(LOWER(src.Unit), '') <> 'cs' THEN src.SalesNumber ELSE NULL END,
        CASE WHEN ISNULL(LOWER(src.Unit), '') <> 'cs' THEN src.PayeeName ELSE NULL END,
        src.ItemId,
        src.ItemName,
        src.ItemName2,
        src.Unit,
        SUM(src.ShipQty),
        SUM(src.BaseShipQty),
        src.Comment,
        src.ShipRoute,
        src.LoadRoute,
        MAX(src.LoadRouteSortGroup),
        MAX(src.LoadRouteSortOrder),
        1,
        0
    FROM #SourceRows AS src
    WHERE src.FactorToBase = 1
    GROUP BY
        src.StorageId,
        src.StorageZone,
        -- Only non-cs units should stay separate by SalesNumber. cs keeps the
        -- original cross-order combine behavior for one simple total line.
        CASE WHEN ISNULL(LOWER(src.Unit), '') <> 'cs' THEN src.SalesNumber ELSE NULL END,
        -- Keep the non-cs customer label aligned with the same split rule.
        CASE WHEN ISNULL(LOWER(src.Unit), '') <> 'cs' THEN src.PayeeName ELSE NULL END,
        src.ItemId,
        src.ItemName,
        src.ItemName2,
        src.Unit,
        src.Comment,
        src.ShipRoute,
        src.RouteOrder,
        src.IsLoadSeparate,
        src.LoadRoute;

    /* Non-base unit items
       These rows were already kept one-per-detail-row. Apply only the same
       Cooler display reclassification here; do not add new aggregation. */
    INSERT INTO #MyItem
    (
        StorageId,
        StorageName,
        SalesNumber,
        PayeeName,
        ItemId,
        ItemName,
        ItemName2,
        Unit,
        ShipQty,
        BaseShipQty,
        Comment,
        ShipRoute,
        LoadRoute,
        LoadRouteSortGroup,
        LoadRouteSortOrder,
        Sort,
        TailSort
    )
    SELECT
        src.StorageId,
        -- Zone classification:
        -- 1. Keep the original zone by default.
        -- 2. Original Cooler rows split into:
        --    Cooler  = cs + lbs
        --    Prepack = other units
        CASE
            WHEN src.StorageZone = 'Cooler' AND ISNULL(LOWER(src.Unit), '') NOT IN ('cs', 'lbs') THEN 'Prepack'
            ELSE src.StorageZone
        END,
        -- Non-base non-cs rows already stay one-per-detail-row; carry source
        -- sale/customer only so TotalSplit can show nested split detail when
        -- the same unit total comes from multiple customers.
        CASE WHEN ISNULL(LOWER(src.Unit), '') <> 'cs' THEN src.SalesNumber ELSE NULL END,
        CASE WHEN ISNULL(LOWER(src.Unit), '') <> 'cs' THEN src.PayeeName ELSE NULL END,
        src.ItemId,
        src.ItemName,
        src.ItemName2,
        src.Unit,
        src.ShipQty,
        src.BaseShipQty,
        src.Comment,
        src.ShipRoute,
        src.LoadRoute,
        src.LoadRouteSortGroup,
        src.LoadRouteSortOrder,
        2,
        0
    FROM #SourceRows AS src
    WHERE src.FactorToBase <> 1;

    /* Customer line
       Keep the customer marker last as before, and give it TailSort=0 because
       the Cooler lbs display rule does not apply to customer header rows. */
    IF @SalesId IS NULL
    BEGIN
        INSERT INTO #MyItem
        (
            StorageName,
            SalesNumber,
            PayeeName,
            ItemName,
            ShipRoute,
            LoadRoute,
            LoadRouteSortGroup,
            LoadRouteSortOrder,
            Sort,
            TailSort
        )
        SELECT
            'Customer',
            NULL,
            NULL,
            sr.PayeeName,
            sr.ShipRoute,
            sr.LoadRoute,
            sr.LoadRouteSortGroup,
            sr.LoadRouteSortOrder,
            3,
            0
        FROM #SalesRows AS sr;
    END;

    SELECT
        m.Id,
        m.StorageId,
        m.StorageName,
        m.SalesNumber,
        m.PayeeName,
        m.ItemId,
        m.ItemName,
        m.ItemName2,
        m.Unit,
        m.ShipQty,
        m.BaseShipQty,
        m.Comment,
        m.ShipRoute,
        m.LoadRoute,
        m.Sort,
        m.TailSort,
        (i.CaseWeight * m.BaseShipQty) AS ItemWeight,
        s.Aisle,
        s.Bay
    FROM #MyItem AS m
    LEFT JOIN Item AS i ON m.ItemId = i.ItemId
    LEFT JOIN ItemStorage AS s ON s.StorageId = m.StorageId
    ORDER BY
        Sort,
        -- 2026-05-01 ET: use the base route fields captured with the row
        -- instead of parsing the displayed LoadRoute string during sorting.
        -- CASE
        --     WHEN LoadRoute = ShipRoute THEN 0
        --     ELSE 1
        -- END,
        -- TRY_CAST(REPLACE(LoadRoute, ShipRoute, '') AS INT) DESC,
        m.LoadRouteSortGroup,
        ISNULL(m.LoadRouteSortOrder, 0) DESC,
        s.SortOrder,
        -- Reclassified cooler lbs rows print at the end of the Cooler group.
        m.TailSort,
        m.ItemName;

    DROP TABLE #MyItem;
    DROP TABLE #SourceRows;
    DROP TABLE #SalesRows;
END;

