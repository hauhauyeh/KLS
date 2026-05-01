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
    DECLARE @UpdatedCount INT = 0;

    IF OBJECT_ID('tempdb..#ActualRoutes') IS NOT NULL DROP TABLE #ActualRoutes;
    IF OBJECT_ID('tempdb..#RouteSummary') IS NOT NULL DROP TABLE #RouteSummary;
    IF OBJECT_ID('tempdb..#RouteAssignmentConflicts') IS NOT NULL DROP TABLE #RouteAssignmentConflicts;
    IF OBJECT_ID('tempdb..#DuplicateRoutes') IS NOT NULL DROP TABLE #DuplicateRoutes;
    IF OBJECT_ID('tempdb..#StaleRoutes') IS NOT NULL DROP TABLE #StaleRoutes;

    ;WITH RouteAssignment AS
    (
        SELECT
            s.ShipDate,
            ShipRoute = LTRIM(RTRIM(s.ShipRoute)),
            TruckNumber = NULLIF(LTRIM(RTRIM(s.TruckNumber)), ''),
            s.Deliverby,
            SalesCount = COUNT(*),
            TruckValueCount = SUM(CASE WHEN NULLIF(LTRIM(RTRIM(s.TruckNumber)), '') IS NOT NULL THEN 1 ELSE 0 END),
            DeliverValueCount = SUM(CASE WHEN s.Deliverby IS NOT NULL THEN 1 ELSE 0 END),
            TruckDistinctCount = COUNT(DISTINCT NULLIF(LTRIM(RTRIM(s.TruckNumber)), '')),
            DeliverDistinctCount = COUNT(DISTINCT s.Deliverby)
        FROM dbo.Sales AS s
        WHERE s.ShipDate = @ShipDate
          AND ISNULL(LTRIM(RTRIM(s.ShipRoute)), '') <> ''
          AND LTRIM(RTRIM(s.ShipRoute)) NOT IN ('X', 'P', 'CM')
        GROUP BY
            s.ShipDate,
            LTRIM(RTRIM(s.ShipRoute)),
            NULLIF(LTRIM(RTRIM(s.TruckNumber)), ''),
            s.Deliverby
    )
    SELECT
        ra.ShipDate,
        ra.ShipRoute,
        TruckNumber = MAX(ra.TruckNumber),
        Deliverby = MAX(ra.Deliverby),
        SalesCount = SUM(ra.SalesCount),
        TruckValueCount = SUM(ra.TruckValueCount),
        DeliverValueCount = SUM(ra.DeliverValueCount),
        TruckDistinctCount = SUM(CASE WHEN ra.TruckNumber IS NOT NULL THEN 1 ELSE 0 END),
        DeliverDistinctCount = SUM(CASE WHEN ra.Deliverby IS NOT NULL THEN 1 ELSE 0 END)
    INTO #RouteSummary
    FROM RouteAssignment AS ra
    GROUP BY
        ra.ShipDate,
        ra.ShipRoute;

    SELECT
        rs.ShipDate,
        rs.ShipRoute,
        rs.TruckNumber,
        Driver = COALESCE(p.PayeeName, CONVERT(VARCHAR(20), rs.Deliverby))
    INTO #ActualRoutes
    FROM #RouteSummary AS rs
    LEFT JOIN dbo.Payee AS p ON p.PayeeId = rs.Deliverby;

    SELECT
        rs.ShipRoute,
        Conflict = CASE
            WHEN rs.TruckDistinctCount > 1 THEN 'Multiple TruckNumber values found in Sales for the same route.'
            WHEN rs.TruckValueCount > 0 AND rs.TruckValueCount < rs.SalesCount THEN 'TruckNumber is only partially assigned in Sales for the same route.'
            WHEN rs.DeliverDistinctCount > 1 THEN 'Multiple Deliverby values found in Sales for the same route.'
            WHEN rs.DeliverValueCount > 0 AND rs.DeliverValueCount < rs.SalesCount THEN 'Deliverby is only partially assigned in Sales for the same route.'
        END
    INTO #RouteAssignmentConflicts
    FROM #RouteSummary AS rs
    WHERE rs.TruckDistinctCount > 1
       OR (rs.TruckValueCount > 0 AND rs.TruckValueCount < rs.SalesCount)
       OR rs.DeliverDistinctCount > 1
       OR (rs.DeliverValueCount > 0 AND rs.DeliverValueCount < rs.SalesCount);

    IF EXISTS (SELECT 1 FROM #RouteAssignmentConflicts)
    BEGIN
        DECLARE @ConflictRoute VARCHAR(50);
        DECLARE @ConflictMessage NVARCHAR(200);
        DECLARE @FinalConflictMessage NVARCHAR(400);

        SELECT TOP 1
            @ConflictRoute = ShipRoute,
            @ConflictMessage = Conflict
        FROM #RouteAssignmentConflicts
        ORDER BY ShipRoute;

        SET @FinalConflictMessage = CONCAT('Cannot sync SalesRoute: route ', @ConflictRoute, '. ', @ConflictMessage);

        THROW 50004, @FinalConflictMessage, 1;
    END

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

    UPDATE sr
    SET
        sr.TruckNumber = ar.TruckNumber,
        sr.Driver = ar.Driver,
        sr.TruckRouteOrder = CASE
            WHEN ar.TruckNumber IS NULL THEN NULL
            ELSE sr.TruckRouteOrder
        END,
        sr.UpdatedAt = GETUTCDATE()
    FROM dbo.SalesRoute AS sr
    INNER JOIN #ActualRoutes AS ar
        ON ar.ShipDate = sr.ShipDate
       AND ar.ShipRoute = LTRIM(RTRIM(sr.ShipRoute))
    WHERE sr.ShipDate = @ShipDate
      AND (ISNULL(sr.TruckNumber, '') <> ISNULL(ar.TruckNumber, '')
       OR ISNULL(sr.Driver, '') <> ISNULL(ar.Driver, '')
       OR (ar.TruckNumber IS NULL AND sr.TruckRouteOrder IS NOT NULL));

    SET @UpdatedCount = @@ROWCOUNT;

    INSERT INTO dbo.SalesRoute
    (
        ShipDate,
        ShipRoute,
        TruckNumber,
        TruckRouteOrder,
        Driver,
        PrintCount,
        CreatedAt
    )
    SELECT
        ar.ShipDate,
        ar.ShipRoute,
        ar.TruckNumber,
        NULL,
        ar.Driver,
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
        DeletedCount = @DeletedCount,
        UpdatedCount = @UpdatedCount;
END
GO
