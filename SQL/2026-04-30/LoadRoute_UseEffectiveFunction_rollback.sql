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

    /* 1) Recompute LoadRoute only for rows where inputs changed */
    IF UPDATE(ShipRoute) OR UPDATE(RouteOrder) OR UPDATE(IsLoadSeparate)
    BEGIN
        UPDATE s
        SET s.LoadRoute =
            CASE
                WHEN i.IsLoadSeparate = 1
                    THEN COALESCE(i.ShipRoute, '') + CONVERT(varchar(12), i.RouteOrder)
                ELSE NULL
            END
        FROM dbo.Sales s
        INNER JOIN inserted i
            ON i.SalesId = s.SalesId;
    END

    /* 2) Clear FIFO fields only for rows where StageId changed 2 -> 0 */
    IF UPDATE(StageId)
    BEGIN
        UPDATE sd
        SET sd.FIFOHistory = NULL,
            sd.FIFOCost    = NULL
        FROM dbo.SalesDetail sd
        INNER JOIN inserted i
            ON i.SalesId = sd.SalesId
        INNER JOIN deleted d
            ON d.SalesId = i.SalesId
        WHERE d.StageId = 2
          AND i.StageId = 0
          AND (sd.FIFOHistory IS NOT NULL OR sd.FIFOCost IS NOT NULL);
    END
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_LoadingList] --[Report_LoadingList] '02/05/2026','E',1
    @ShipDate DATE,
    @ShipRoute NVARCHAR(50),
    @IsLoad BIT
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    CREATE TABLE #MyPacking
    (
        AutoId INT IDENTITY(1,1),
        Department NVARCHAR(100),
        DepartmentOrder INT,
        StorageName NVARCHAR(255),
        ItemCode NVARCHAR(50),
        ItemName NVARCHAR(255),
        Comment NVARCHAR(255),
        ShipQty DECIMAL(18,2),
        Unit NVARCHAR(50),
        ShipRoute NVARCHAR(10),
        LoadRoute NVARCHAR(10)
    );

    INSERT INTO #MyPacking
    SELECT st.Zone,
    st.SortOrder,
    st.Section,
    i.ItemCode,
    i.ItemName,
    sd.Notes,
    SUM(sd.ShipQty),
    sd.Unit,
    s.ShipRoute,
    ISNULL(s.LoadRoute,s.ShipRoute)
    FROM Sales AS s INNER JOIN SalesDetail AS sd ON s.SalesId=sd.SalesId
    INNER JOIN Item AS i ON sd.ItemId=i.ItemId
    LEFT JOIN ItemStorage as st on st.StorageId=i.StorageId
    WHERE s.ShipDate=@ShipDate AND sd.ShipQty>0
    AND s.ShipRoute=CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
    GROUP BY st.Zone,st.SortOrder,st.Section,i.ItemCode,i.ItemName,sd.Notes,sd.Unit,s.ShipRoute,s.LoadRoute;

    SELECT m.*,i.ItemBoxDesc
    FROM #MyPacking AS m INNER JOIN Item as i ON m.ItemCode=i.ItemCode
    ORDER BY
    CASE
        WHEN LoadRoute=ShipRoute THEN 0
        ELSE 1
    END,
    TRY_CAST(REPLACE(LoadRoute, ShipRoute, '') AS INT) DESC,
    DepartmentOrder,m.StorageName,ItemName;

    DROP TABLE #MyPacking;
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
        ItemId       INT,
        ItemName     NVARCHAR(255),
        ItemName2    NVARCHAR(255),
        Unit         NVARCHAR(100),
        ShipQty      DECIMAL(18,2),
        BaseShipQty  DECIMAL(18,6),
        Comment      NVARCHAR(255),
        ShipRoute    NVARCHAR(10),
        LoadRoute    NVARCHAR(10),
        Sort         INT
    );

    /* Base unit items */
    INSERT INTO #MyItem
    (
        StorageId,
        StorageName,
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
        st.Zone,
        sd.ItemId,
        i.ItemName,
        i.ItemName2,
        sd.Unit,
        SUM(sd.ShipQty),
        SUM(sd.BaseShipQty),
        sd.Notes,
        s.ShipRoute,
        ISNULL(s.LoadRoute, s.ShipRoute),
        1
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Item AS i ON i.ItemId = sd.ItemId
    LEFT JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    WHERE sd.FactorToBase = 1
      AND s.ShipDate = CASE WHEN @ShipDate IS NOT NULL THEN @ShipDate ELSE s.ShipDate END
      AND s.ShipRoute = CASE WHEN @ShipRoute IS NOT NULL THEN @ShipRoute ELSE s.ShipRoute END
      AND s.SalesId = CASE WHEN @SalesId IS NOT NULL THEN @SalesId ELSE s.SalesId END
    GROUP BY
        i.StorageId,
        st.Zone,
        sd.ItemId,
        i.ItemName,
        i.ItemName2,
        sd.Unit,
        sd.Notes,
        s.ShipRoute,
        s.LoadRoute;

    /* Non-base unit items */
    INSERT INTO #MyItem
    (
        StorageId,
        StorageName,
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
        st.Zone,
        sd.ItemId,
        i.ItemName,
        i.ItemName2,
        sd.Unit,
        sd.ShipQty,
        sd.BaseShipQty,
        sd.Notes,
        s.ShipRoute,
        ISNULL(s.LoadRoute, s.ShipRoute),
        2
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Item AS i ON i.ItemId = sd.ItemId
    LEFT JOIN ItemStorage AS st ON st.StorageId = i.StorageId
    WHERE sd.FactorToBase <> 1
      AND s.ShipDate = CASE WHEN @ShipDate IS NOT NULL THEN @ShipDate ELSE s.ShipDate END
      AND s.ShipRoute = CASE WHEN @ShipRoute IS NOT NULL THEN @ShipRoute ELSE s.ShipRoute END
      AND s.SalesId = CASE WHEN @SalesId IS NOT NULL THEN @SalesId ELSE s.SalesId END;

    /* Customer line */
    IF @SalesId IS NULL
    BEGIN
        INSERT INTO #MyItem
        (
            StorageName,
            ItemName,
            ShipRoute,
            LoadRoute,
            Sort
        )
        SELECT
            'Customer',
            p.PayeeName,
            s.ShipRoute,
            ISNULL(s.LoadRoute, s.ShipRoute),
            3
        FROM Sales AS s
        INNER JOIN Payee AS p ON s.ShipId = p.PayeeId
        WHERE  s.ShipDate = CASE WHEN @ShipDate IS NOT NULL THEN @ShipDate ELSE s.ShipDate END
          AND s.ShipRoute = CASE WHEN @ShipRoute IS NOT NULL THEN @ShipRoute ELSE s.ShipRoute END
          AND s.SalesId = CASE WHEN @SalesId IS NOT NULL THEN @SalesId ELSE s.SalesId END;
    END;

    SELECT
        m.*,
        (i.CaseWeight*m.BaseShipQty) AS ItemWeight,
        s.Aisle,
        s.Bay
    FROM #MyItem AS m
    LEFT JOIN Item AS i ON m.ItemId = i.ItemId
    LEFT JOIN ItemStorage AS s ON s.StorageId = m.StorageId
    ORDER BY
        Sort,
        CASE
            WHEN LoadRoute=ShipRoute THEN 0
            ELSE 1
        END,
        TRY_CAST(REPLACE(LoadRoute, ShipRoute, '') AS INT) DESC,
        s.SortOrder,
        m.ItemName;

    DROP TABLE #MyItem;
END
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
            ISNULL(s.LoadRoute, s.ShipRoute) AS LoadRoute,
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
        WHERE
            s.ShipDate = @ShipDate
            AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
            AND (
                    (st.Zone = 'Cooler'
                     AND sd.ShipQty > 0
                     AND sd.Unit NOT IN ('cs', 'lbs'))
                 OR (st.Zone = 'Store'
                     AND sd.ShipQty > 0)
                )
    )
    SELECT * FROM cte
    ORDER BY
        CASE
            WHEN LoadRoute=ShipRoute THEN 0
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

    SELECT ROW_NUMBER() OVER(ORDER BY i.ItemName,ShipRoute) AS Id,
    s.ShipDate,
    i.ItemName,
    ISNULL(s.LoadRoute,s.ShipRoute) AS ShipRoute,
    sd.Unit,
    SUM(sd.ShipQty) AS ShipQty
    FROM Sales AS s INNER JOIN SalesDetail AS sd on s.SalesId=sd.SalesId
    INNER JOIN Item AS i ON sd.ItemId=i.ItemId
    WHERE s.ShipDate=@ShipDate AND i.ItemCode IN ('MUM','BS','MILK','MRE') AND s.ShipRoute NOT IN ('X','P')
    GROUP BY s.ShipDate,s.ShipRoute,LoadRoute,sd.Unit,i.ItemName
    ORDER BY i.ItemName,ShipRoute;
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
            s.LoadRoute,
            s.StageId,
            s.IsLocked
        FROM TempBombSales t
        INNER JOIN Item  i ON t.ItemId = i.ItemId
        INNER JOIN Payee p ON t.PayeeId = p.PayeeId
        INNER JOIN Sales s ON s.SalesId = t.SalesId
        WHERE t.EmpId = @EmpId
          AND (
                t.UnitPrice = 0
                OR (t.Unit = 'lb'  AND t.ShipQty = 1 AND t.IsUserOverWrite = 0)
                OR (t.Unit = 'lbs' AND t.ShipQty >= 1 AND t.IsUserOverWrite = 0)
                OR (t.Unit = 'lbs' AND t.ShipQty = 1 AND t.IsUserOverWrite = 1)
              )
        ORDER BY
            s.ShipDate DESC,
            s.ShipRoute,
            CASE
                WHEN LoadRoute IS NULL THEN 0
                ELSE 1
            END,
            TRY_CAST(REPLACE(LoadRoute, ShipRoute, '') AS INT) DESC,
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
            s.LoadRoute,
            s.StageId,
            s.IsLocked
        FROM TempBombSales t
        INNER JOIN Item  i ON t.ItemId = i.ItemId
        INNER JOIN Payee p ON t.PayeeId = p.PayeeId
        INNER JOIN Sales s ON s.SalesId = t.SalesId
        WHERE t.EmpId = @EmpId AND (@TempId IS NULL OR t.TempBombId = @TempId)
        ORDER BY
            s.ShipDate DESC,
            s.ShipRoute,
            CASE
                WHEN LoadRoute IS NULL THEN 0
                ELSE 1
            END,
            TRY_CAST(REPLACE(LoadRoute, ShipRoute, '') AS INT) DESC,
            p.PayeeName,
            s.SalesNumber;
    END
END;
GO

IF OBJECT_ID('dbo.Fn_Calc_EffectiveLoadRoute', 'FN') IS NOT NULL
    DROP FUNCTION dbo.Fn_Calc_EffectiveLoadRoute;
GO
