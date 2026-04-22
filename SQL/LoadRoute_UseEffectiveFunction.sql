SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER TRIGGER [dbo].[TRG_Update_Sales]
ON dbo.Sales
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
END
GO

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
        Sort         INT
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
        Sort
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
        -- Only non-cs units need the source order/customer carried through.
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
        1
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
        Sort
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
        2
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
       Keep the customer marker last as before. */
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
            Sort
        )
        SELECT
            'Customer',
            NULL,
            NULL,
            p.PayeeName,
            s.ShipRoute,
            dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate),
            3
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
        m.ItemName;

    DROP TABLE #MyItem;
END;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_PackingLabel]
    -- EXEC [Report_PackingLabel] '02/05/2026', 'E'
    @ShipDate   DATE,
    @ShipRoute  NVARCHAR(50)
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    ;WITH cte AS
    (
        SELECT
            ROW_NUMBER() OVER (ORDER BY s.ShipRoute, p.PayeeName) AS Id,
            s.SalesNumber,
            s.ShipDate,
            s.ShipRoute,
            sd.ShipQty,
            sd.Unit,
            i.ItemName,
            p.PayeeName,
            RIGHT(s.SalesNumber, 3) AS Last3Digit,
            s.RouteOrder,
            sd.Notes,
            st.Zone AS Department,
            st.SortOrder,
            dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate) AS LoadRoute,
            (
                SELECT TruckNumber
                FROM SalesRoute
                WHERE ShipDate = s.ShipDate
                  AND ShipRoute = s.ShipRoute
            ) AS TruckNumber
        FROM Sales AS s
        INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
        INNER JOIN Item AS i ON i.ItemId = sd.ItemId
        INNER JOIN Payee AS p ON p.PayeeId = s.ShipId
        LEFT JOIN ItemStorage AS st ON st.StorageId = i.StorageId
        WHERE s.ShipDate = @ShipDate
          AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
          AND (
                (st.Zone = 'Cooler' AND sd.ShipQty > 0 AND sd.Unit NOT IN ('cs', 'lbs'))
                OR (st.Zone = 'Store' AND sd.ShipQty > 0)
              )
    )
    SELECT * FROM cte
    ORDER BY
        CASE
            WHEN LoadRoute = ShipRoute THEN 0
            ELSE 1
        END,
        TRY_CAST(REPLACE(LoadRoute, ShipRoute, '') AS INT) DESC,
        SortOrder DESC,
        ItemName,
        PayeeName;
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_Sensitive] --[Report_Sensitive] '02/02/2022'
    @ShipDate DATE
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    SELECT
        ROW_NUMBER() OVER (ORDER BY i.ItemName, EffectiveLoadRoute) AS Id,
        s.ShipDate,
        i.ItemName,
        EffectiveLoadRoute AS ShipRoute,
        sd.Unit,
        SUM(sd.ShipQty) AS ShipQty
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    CROSS APPLY
    (
        SELECT dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate) AS EffectiveLoadRoute
    ) AS lr
    WHERE s.ShipDate = @ShipDate
      AND i.ItemCode IN ('MUM', 'BS', 'MILK', 'MRE')
      AND s.ShipRoute NOT IN ('X', 'P')
    GROUP BY
        s.ShipDate,
        i.ItemName,
        lr.EffectiveLoadRoute,
        sd.Unit
    ORDER BY
        i.ItemName,
        EffectiveLoadRoute;
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[TempBombSales_GetList]
    @EmpId      INT,
    @CheckAgain BIT,
    @TempId     INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @CheckAgain = 1
    BEGIN
        SELECT TOP (500)
            t.*,
            p.PayeeName,
            i.ItemName,
            i.ItemCode,
            s.ShipDate,
            s.ShipRoute,
            dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate) AS LoadRoute,
            s.StageId,
            s.IsLocked
        FROM TempBombSales t
        INNER JOIN Item i ON t.ItemId = i.ItemId
        INNER JOIN Payee p ON t.PayeeId = p.PayeeId
        INNER JOIN Sales s ON s.SalesId = t.SalesId
        WHERE t.EmpId = @EmpId
          AND (
                t.UnitPrice = 0
                OR (t.Unit = 'lb' AND t.ShipQty = 1 AND t.IsUserOverWrite = 0)
                OR (t.Unit = 'lbs' AND t.ShipQty >= 1 AND t.IsUserOverWrite = 0)
                OR (t.Unit = 'lbs' AND t.ShipQty = 1 AND t.IsUserOverWrite = 1)
              )
        ORDER BY
            s.ShipDate DESC,
            s.ShipRoute,
            CASE
                WHEN dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate) = s.ShipRoute THEN 0
                ELSE 1
            END,
            TRY_CAST(REPLACE(dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate), s.ShipRoute, '') AS INT) DESC,
            p.PayeeName,
            s.SalesNumber;
    END
    ELSE
    BEGIN
        SELECT TOP (500)
            t.*,
            p.PayeeName,
            i.ItemName,
            i.ItemCode,
            s.ShipDate,
            s.ShipRoute,
            dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate) AS LoadRoute,
            s.StageId,
            s.IsLocked
        FROM TempBombSales t
        INNER JOIN Item i ON t.ItemId = i.ItemId
        INNER JOIN Payee p ON t.PayeeId = p.PayeeId
        INNER JOIN Sales s ON s.SalesId = t.SalesId
        WHERE t.EmpId = @EmpId
          AND (@TempId IS NULL OR t.TempBombId = @TempId)
        ORDER BY
            s.ShipDate DESC,
            s.ShipRoute,
            CASE
                WHEN dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate) = s.ShipRoute THEN 0
                ELSE 1
            END,
            TRY_CAST(REPLACE(dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate), s.ShipRoute, '') AS INT) DESC,
            p.PayeeName,
            s.SalesNumber;
    END
END;
GO
