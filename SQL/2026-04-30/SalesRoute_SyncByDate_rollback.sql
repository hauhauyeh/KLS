SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SalesRoute_SyncByDate]
    @ShipDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @ShipDate IS NULL
        THROW 50001, 'ShipDate is required.', 1;

    DECLARE @InsertedCount INT = 0;
    DECLARE @DeletedCount INT = 0;

    IF OBJECT_ID('tempdb..#ActualRoutes') IS NOT NULL DROP TABLE #ActualRoutes;
    IF OBJECT_ID('tempdb..#DuplicateRoutes') IS NOT NULL DROP TABLE #DuplicateRoutes;
    IF OBJECT_ID('tempdb..#StaleRoutes') IS NOT NULL DROP TABLE #StaleRoutes;

    SELECT DISTINCT
        s.ShipDate,
        ShipRoute = LTRIM(RTRIM(s.ShipRoute))
    INTO #ActualRoutes
    FROM dbo.Sales AS s
    WHERE s.ShipDate = @ShipDate
      AND ISNULL(LTRIM(RTRIM(s.ShipRoute)), '') <> ''
      AND LTRIM(RTRIM(s.ShipRoute)) NOT IN ('X', 'P', 'CM');

    ;WITH Dedup AS
    (
        SELECT
            sr.SalesRouteId,
            sr.ShipRoute,
            RN = ROW_NUMBER() OVER (
                PARTITION BY sr.ShipDate, LTRIM(RTRIM(sr.ShipRoute))
                ORDER BY sr.SalesRouteId
            )
        FROM dbo.SalesRoute AS sr
        WHERE sr.ShipDate = @ShipDate
    )
    SELECT d.SalesRouteId, d.ShipRoute
    INTO #DuplicateRoutes
    FROM Dedup AS d
    WHERE d.RN > 1;

    IF EXISTS (
        SELECT 1
        FROM #DuplicateRoutes AS d
        INNER JOIN dbo.SalesRouteDetail AS rd ON rd.SalesRouteId = d.SalesRouteId
    )
    BEGIN
        THROW 50002, 'Cannot sync SalesRoute: duplicate route rows exist with SalesRouteDetail rows.', 1;
    END

    DELETE sr
    FROM dbo.SalesRoute AS sr
    INNER JOIN #DuplicateRoutes AS d ON d.SalesRouteId = sr.SalesRouteId;

    SET @DeletedCount += @@ROWCOUNT;

    SELECT sr.SalesRouteId, sr.ShipRoute
    INTO #StaleRoutes
    FROM dbo.SalesRoute AS sr
    LEFT JOIN #ActualRoutes AS ar
        ON ar.ShipDate = sr.ShipDate
       AND ar.ShipRoute = LTRIM(RTRIM(sr.ShipRoute))
    WHERE sr.ShipDate = @ShipDate
      AND ar.ShipRoute IS NULL;

    IF EXISTS (
        SELECT 1
        FROM #StaleRoutes AS st
        INNER JOIN dbo.SalesRouteDetail AS rd ON rd.SalesRouteId = st.SalesRouteId
    )
    BEGIN
        THROW 50003, 'Cannot sync SalesRoute: stale route rows exist with SalesRouteDetail rows.', 1;
    END

    DELETE sr
    FROM dbo.SalesRoute AS sr
    INNER JOIN #StaleRoutes AS st ON st.SalesRouteId = sr.SalesRouteId;

    SET @DeletedCount += @@ROWCOUNT;

    INSERT INTO dbo.SalesRoute
    (
        ShipDate,
        ShipRoute,
        PrintCount,
        CreatedAt
    )
    SELECT
        ar.ShipDate,
        ar.ShipRoute,
        0,
        GETUTCDATE()
    FROM #ActualRoutes AS ar
    LEFT JOIN dbo.SalesRoute AS sr
        ON sr.ShipDate = ar.ShipDate
       AND LTRIM(RTRIM(sr.ShipRoute)) = ar.ShipRoute
    WHERE sr.SalesRouteId IS NULL;

    SET @InsertedCount = @@ROWCOUNT;

    SELECT
        InsertedCount = @InsertedCount,
        DeletedCount = @DeletedCount;
END
GO
