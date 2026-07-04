-- =============================================================================
-- Report_PackingList -- deploy (DROP + CREATE). Working file per SP workflow.
-- 2026-07-03: remove the SalesDetail.FactorToBase dependency (note-packing-report-map.md §11).
--   FactorToBase was used ONLY to split rows into a base branch (WHERE FactorToBase=1
--   -> SUM/GROUP BY, Sort=1) and a non-base branch (WHERE FactorToBase<>1 -> per-detail,
--   Sort=2). It is NOT in the SP output; the C# builders never read it and re-aggregate
--   by Unit NAME anyway (verified §10.3/§11.1). So the split is redundant: emit ONE flat
--   per-detail row set and let the backend SUM by Unit once (same totals as the old
--   SP-then-backend double-SUM). Base/non-base is the WRONG concept for packing -- the real
--   combine signal is Unit='cs' (bulk pick), kept name-based here (§10.4, decision §11.0).
--   Pure refactor: all data is MultipleToBase=1, so no behavior change expected.
--   Acceptance: diff rendered output of Packing List / Total List / Total Split / Loading List
--   packing section for a real ShipDate before vs after -- totals, cs combined lines, and
--   Prepack customer splits must be identical.
-- Baseline: KLS/SQL/2026-07-03/Report_PackingList_live_baseline.sql
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Report_PackingList]
GO

CREATE   PROCEDURE [dbo].[Report_PackingList] --[Report_PackingList] '02/05/2026','E',null
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
        -- 2026-07-03: removed FactorToBase DECIMAL(18,6) NULL -- was only used for the
        -- base/non-base split, now retired (backend aggregates by Unit name).
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
        -- 2026-07-03: FactorToBase dropped from this list.
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
        -- 2026-07-03: sd.FactorToBase select removed.
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

    /* All packing detail rows -- ONE flat insert (2026-07-03).
       Formerly two branches split on FactorToBase: base (=1) was SUM/GROUP BY'd here
       (Sort=1) and non-base (<>1) emitted per-detail (Sort=2). That pre-aggregation is
       redundant -- the C# builders re-aggregate by Unit name -- so we emit every line
       per-detail and let the backend SUM once. cs still combines across orders because
       its SalesNumber/PayeeName are nulled below (name-based, not factor-based). */
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
        -- Only non-cs units carry source order/customer. cs is nulled so the backend
        -- combines it into one cross-order line (this is the old base-branch cs rule,
        -- kept name-based). Non-cs keeps SalesNumber -> stays per-order.
        CASE WHEN ISNULL(LOWER(src.Unit), '') <> 'cs' THEN src.SalesNumber ELSE NULL END,
        CASE WHEN ISNULL(LOWER(src.Unit), '') <> 'cs' THEN src.PayeeName ELSE NULL END,
        src.ItemId,
        src.ItemName,
        src.ItemName2,
        src.Unit,
        -- per-detail qty (no SUM here); the backend aggregates by Unit name.
        src.ShipQty,
        src.BaseShipQty,
        src.Comment,
        src.ShipRoute,
        src.LoadRoute,
        src.LoadRouteSortGroup,
        src.LoadRouteSortOrder,
        -- Sort: base/non-base (1/2) distinction retired with FactorToBase. All detail rows
        -- share Sort=1; customer marker stays Sort=3. Ordering is cosmetic -- the backend
        -- re-groups/re-orders (PackingStorageOrder). Verify visually in acceptance.
        1,
        0
    FROM #SourceRows AS src;

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
GO
