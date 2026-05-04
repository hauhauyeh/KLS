
CREATE   PROCEDURE [dbo].[Report_PackingList] --[Report_PackingList] '02/05/2026','E',null
    @ShipDate   DATE,
    @ShipRoute  NVARCHAR(50),
    @SalesId    INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);

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
        Sort         INT,
        -- Report-only tie breaker inside one storage group.
        -- Used to push reclassified cooler lbs rows to the end of Cooler.
        TailSort     INT
    );

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
        Sort,
        TailSort
    )
    SELECT
        i.StorageId,
        -- Zone classification:
        -- 1. Keep the original zone by default.
        -- 2. Original Cooler rows split into:
        --    Cooler  = cs + lbs
        --    Prepack = other units
        CASE
            WHEN st.Zone = 'Cooler' AND ISNULL(LOWER(sd.Unit), '') NOT IN ('cs', 'lbs') THEN 'Prepack'
            ELSE st.Zone
        END,
        -- Only non-cs units need source order/customer carried through.
        CASE WHEN ISNULL(LOWER(sd.Unit), '') <> 'cs' THEN s.SalesNumber ELSE NULL END,
        CASE WHEN ISNULL(LOWER(sd.Unit), '') <> 'cs' THEN p.PayeeName ELSE NULL END,
        sd.ItemId,
        i.ItemName,
        i.ItemName2,
        sd.Unit,
        SUM(sd.ShipQty),
        SUM(sd.BaseShipQty),
        sd.Notes,
        s.ShipRoute,
        dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate),
        1,
        0
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Item AS i ON i.ItemId = sd.ItemId
    INNER JOIN Payee AS p ON p.PayeeId = s.ShipId
    LEFT JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    WHERE sd.FactorToBase = 1
      -- Report-only cleanup: exclude any negative-qty source detail row before
      -- packing aggregation, rather than filtering by the grouped result.
      AND sd.ShipQty >= 0
      AND s.ShipDate = CASE WHEN @ShipDate IS NOT NULL THEN @ShipDate ELSE s.ShipDate END
      AND s.ShipRoute = CASE WHEN @ShipRoute IS NOT NULL THEN @ShipRoute ELSE s.ShipRoute END
      AND s.SalesId = CASE WHEN @SalesId IS NOT NULL THEN @SalesId ELSE s.SalesId END
    GROUP BY
        i.StorageId,
        st.Zone,
        -- Only non-cs units should stay separate by SalesNumber. cs keeps the
        -- original cross-order combine behavior for one simple total line.
        CASE WHEN ISNULL(LOWER(sd.Unit), '') <> 'cs' THEN s.SalesNumber ELSE NULL END,
        -- Keep the non-cs customer label aligned with the same split rule.
        CASE WHEN ISNULL(LOWER(sd.Unit), '') <> 'cs' THEN p.PayeeName ELSE NULL END,
        sd.ItemId,
        i.ItemName,
        i.ItemName2,
        sd.Unit,
        sd.Notes,
        s.ShipRoute,
        s.RouteOrder,
        s.IsLoadSeparate;

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
        Sort,
        TailSort
    )
    SELECT
        i.StorageId,
        -- Zone classification:
        -- 1. Keep the original zone by default.
        -- 2. Original Cooler rows split into:
        --    Cooler  = cs + lbs
        --    Prepack = other units
        CASE
            WHEN st.Zone = 'Cooler' AND ISNULL(LOWER(sd.Unit), '') NOT IN ('cs', 'lbs') THEN 'Prepack'
            ELSE st.Zone
        END,
        -- Non-base non-cs rows already stay one-per-detail-row; carry source
        -- sale/customer only so TotalSplit can show nested split detail when
        -- the same unit total comes from multiple customers.
        CASE WHEN ISNULL(LOWER(sd.Unit), '') <> 'cs' THEN s.SalesNumber ELSE NULL END,
        CASE WHEN ISNULL(LOWER(sd.Unit), '') <> 'cs' THEN p.PayeeName ELSE NULL END,
        sd.ItemId,
        i.ItemName,
        i.ItemName2,
        sd.Unit,
        sd.ShipQty,
        sd.BaseShipQty,
        sd.Notes,
        s.ShipRoute,
        dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate),
        2,
        0
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Item AS i ON i.ItemId = sd.ItemId
    INNER JOIN Payee AS p ON p.PayeeId = s.ShipId
    LEFT JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    WHERE sd.FactorToBase <> 1
      -- Report-only cleanup: hide negative item qty rows from the packing output.
      AND sd.ShipQty >= 0
      AND s.ShipDate = CASE WHEN @ShipDate IS NOT NULL THEN @ShipDate ELSE s.ShipDate END
      AND s.ShipRoute = CASE WHEN @ShipRoute IS NOT NULL THEN @ShipRoute ELSE s.ShipRoute END
      AND s.SalesId = CASE WHEN @SalesId IS NOT NULL THEN @SalesId ELSE s.SalesId END;

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
            Sort,
            TailSort
        )
        SELECT
            'Customer',
            NULL,
            NULL,
            p.PayeeName,
            s.ShipRoute,
            dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate),
            3,
            0
        FROM Sales AS s
        INNER JOIN Payee AS p ON s.ShipId = p.PayeeId
        WHERE s.ShipDate = CASE WHEN @ShipDate IS NOT NULL THEN @ShipDate ELSE s.ShipDate END
          AND s.ShipRoute = CASE WHEN @ShipRoute IS NOT NULL THEN @ShipRoute ELSE s.ShipRoute END
          AND s.SalesId = CASE WHEN @SalesId IS NOT NULL THEN @SalesId ELSE s.SalesId END;
    END;

    SELECT
        m.*,
        (i.CaseWeight * m.BaseShipQty) AS ItemWeight,
        s.Aisle,
        s.Bay
    FROM #MyItem AS m
    LEFT JOIN Item AS i ON m.ItemId = i.ItemId
    LEFT JOIN ItemStorage AS s ON s.StorageId = m.StorageId
    ORDER BY
        Sort,
        CASE
            WHEN LoadRoute = ShipRoute THEN 0
            ELSE 1
        END,
        TRY_CAST(REPLACE(LoadRoute, ShipRoute, '') AS INT) DESC,
        s.SortOrder,
        -- Reclassified cooler lbs rows print at the end of the Cooler group.
        m.TailSort,
        m.ItemName;

    DROP TABLE #MyItem;
END;

