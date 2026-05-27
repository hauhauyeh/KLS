SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Scheduler_ImportDriverTimesheet];
GO


CREATE PROCEDURE [dbo].[Scheduler_ImportDriverTimesheet]
AS
BEGIN
    SET NOCOUNT ON;

    /*
      Daily scheduler (runs ~11am) ƒ?" imports today's driver AND loader
      assignments from SalesRoute into each crew member's Timesheet for today.

      Driver behavior (existing, unchanged):
        1. One Timesheet per (Driver, today). If the driver already has a
           Timesheet for today (manual or prior auto-sync run), reuse it.
           Otherwise create a new one with Notes='Auto Sync'.
        2. Each imported route becomes a TimesheetDetail under that Timesheet
           with Notes='Auto Sync $1,234.56' where the dollar amount is the
           route's total Sales for that ShipDate+ShipRoute (same calc as
           Report_JobSummary's RouteTotal column).
        3. Idempotent ƒ?" duplicate guard is scoped to (TimesheetId, JobCode='D',
           Route). A Driver row and a Loader row on the same route are
           different jobs; both can coexist.

      Loader behavior (added 2026-05-25, Phase 2):
        Parallel loop using SalesRoute.LoaderId (FK added 2026-05-25 Phase 1).
        Same shape as the driver loop except:
        - JobCode = 'L' instead of 'D'.
        - JobRate from EmpJob where JobCode='L'.
        - Detail Notes formatted as 'System Loader ($1,234.56)' so loader
          rows are visually distinguishable from driver rows in the
          timesheet UI and reports.
        - Dedup guard scoped to (TimesheetId, JobCode='L', Route), so a
          driver detail and a loader detail can coexist for the same person
          on the same route (when one person both drives and loads).

      Source filter (both loops):
        - SalesRoute.DriverId / .LoaderId IS NOT NULL (the real FK; the
          text columns are denormalized display caches).
        - Route NOT IN ('P', 'CM') ƒ?" these route codes are scheduling
          artifacts that should never produce a crew timesheet entry.
    */

    DECLARE @CompanyTimezone NVARCHAR(100)
    SELECT @CompanyTimezone = Timezone FROM Company

    -- =====================================================================
    -- Driver loop (existing behavior, unchanged)
    -- =====================================================================

    DECLARE @TimeTable AS TABLE
    (
        Id INT IDENTITY(1,1),
        ShipDate DATE,
        ShipRoute NVARCHAR(10),
        DriverId INT
    )

    DECLARE @MaxRow INT
    DECLARE @RowNum INT = 1
    DECLARE @ShipDate DATETIME
    DECLARE @ShipDateOnly DATE
    DECLARE @ShipRoute NVARCHAR(10)
    DECLARE @DriverId INT
    DECLARE @TimesheetNumber INT
    DECLARE @TimesheetId INT
    DECLARE @JobRate DECIMAL(18,2)
    DECLARE @RouteTotal DECIMAL(18,2)
    DECLARE @DetailNotes NVARCHAR(200)

    SELECT @JobRate = JobRate FROM EmpJob WHERE JobCode = 'D'

    -- Source filter: real FK + exclude non-driver scheduling codes.
    INSERT INTO @TimeTable
    SELECT s.ShipDate, s.ShipRoute, s.DriverId
    FROM SalesRoute AS s
    WHERE s.ShipDate = CONVERT(date, GETDATE())
      AND s.DriverId IS NOT NULL
      AND s.ShipRoute NOT IN ('P', 'CM')

    SELECT @MaxRow = COUNT(*) FROM @TimeTable

    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT @ShipDateOnly = ShipDate,
               @ShipRoute    = ShipRoute,
               @DriverId     = DriverId
        FROM @TimeTable WHERE Id = @RowNum

        -- Look for an existing Timesheet for (Driver, today). Match on the
        -- date part of InTime in company local-time terms.
        SET @TimesheetId = NULL;
        SELECT TOP (1) @TimesheetId = TimesheetId
        FROM [dbo].[Timesheet]
        WHERE PayeeId = @DriverId
          AND CAST(InTime AT TIME ZONE 'UTC' AT TIME ZONE @CompanyTimezone AS DATE) = @ShipDateOnly
        ORDER BY TimesheetId;

        -- No existing Timesheet ƒ+' create one (with Notes='Auto Sync' since
        -- it's entirely system-created).
        IF @TimesheetId IS NULL
        BEGIN
            SET @TimesheetNumber = NEXT VALUE FOR dbo.Seq_TimesheetNumber;

            -- Default to 9am local, converted to UTC.
            SET @ShipDate = (SELECT CAST(@ShipDateOnly AS DATETIME) + '09:00:00'
                AT TIME ZONE @CompanyTimezone AT TIME ZONE 'UTC')

            INSERT INTO [dbo].[Timesheet]
               ([TimesheetNumber]
               ,[PayeeId]
               ,[InTime]
               ,[Notes]
               ,[CreatedAt])
            VALUES
               (@TimesheetNumber
               ,@DriverId
               ,@ShipDate
               ,'Auto Sync'
               ,GETUTCDATE())

            SELECT @TimesheetId = SCOPE_IDENTITY();
        END

        -- Compute route's Sales total ƒ?" same calc as Report_JobSummary's
        -- RouteTotal column.
        SELECT @RouteTotal = ISNULL(SUM(SalesTotal), 0)
        FROM dbo.Sales
        WHERE ShipDate = @ShipDateOnly
          AND ShipRoute = @ShipRoute;

        -- Build the marker + formatted dollar amount: 'Auto Sync $1,234.56'.
        SET @DetailNotes = 'Auto Sync ' + FORMAT(@RouteTotal, 'C', 'en-US');

        -- Insert the route as a TimesheetDetail. Dedup guard is scoped to
        -- JobCode='D' so a Driver detail can coexist with a Loader detail
        -- on the same route.
        IF NOT EXISTS (
            SELECT 1 FROM [dbo].[TimesheetDetail]
            WHERE TimesheetId = @TimesheetId
              AND JobCode = 'D'
              AND Route = @ShipRoute
        )
        BEGIN
            INSERT INTO [dbo].[TimesheetDetail]
               ([TimesheetId]
               ,[JobCode]
               ,[Qty]
               ,[JobRate]
               ,[ExtTotal]
               ,[Route]
               ,[Notes])
            VALUES
               (@TimesheetId
               ,'D'
               ,1
               ,@JobRate
               ,@JobRate
               ,@ShipRoute
               ,@DetailNotes)
        END

        SET @RowNum += 1
    END

    -- =====================================================================
    -- Loader loop (added 2026-05-25, Phase 2)
    -- Parallel structure to the driver loop; chose duplication over a unified
    -- crew-table loop so a future reader sees the loader path mirror the
    -- driver path one-for-one and either can be edited independently without
    -- risking the other.
    -- =====================================================================

    DECLARE @LoaderTable AS TABLE
    (
        Id INT IDENTITY(1,1),
        ShipDate DATE,
        ShipRoute NVARCHAR(10),
        LoaderId INT
    )

    DECLARE @LoaderId INT
    DECLARE @LoaderJobRate DECIMAL(18,2)
    DECLARE @LoaderDetailNotes NVARCHAR(200)

    SELECT @LoaderJobRate = JobRate FROM EmpJob WHERE JobCode = 'L'

    INSERT INTO @LoaderTable
    SELECT s.ShipDate, s.ShipRoute, s.LoaderId
    FROM SalesRoute AS s
    WHERE s.ShipDate = CONVERT(date, GETDATE())
      AND s.LoaderId IS NOT NULL
      AND s.ShipRoute NOT IN ('P', 'CM')

    SET @RowNum = 1
    SELECT @MaxRow = COUNT(*) FROM @LoaderTable

    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT @ShipDateOnly = ShipDate,
               @ShipRoute    = ShipRoute,
               @LoaderId     = LoaderId
        FROM @LoaderTable WHERE Id = @RowNum

        -- Look for an existing Timesheet for (Loader, today). Same logic as
        -- the driver loop -- reuse manual / earlier-auto-sync header when
        -- present, else create a fresh 9am-local header.
        SET @TimesheetId = NULL;
        SELECT TOP (1) @TimesheetId = TimesheetId
        FROM [dbo].[Timesheet]
        WHERE PayeeId = @LoaderId
          AND CAST(InTime AT TIME ZONE 'UTC' AT TIME ZONE @CompanyTimezone AS DATE) = @ShipDateOnly
        ORDER BY TimesheetId;

        IF @TimesheetId IS NULL
        BEGIN
            SET @TimesheetNumber = NEXT VALUE FOR dbo.Seq_TimesheetNumber;

            SET @ShipDate = (SELECT CAST(@ShipDateOnly AS DATETIME) + '09:00:00'
                AT TIME ZONE @CompanyTimezone AT TIME ZONE 'UTC')

            INSERT INTO [dbo].[Timesheet]
               ([TimesheetNumber]
               ,[PayeeId]
               ,[InTime]
               ,[Notes]
               ,[CreatedAt])
            VALUES
               (@TimesheetNumber
               ,@LoaderId
               ,@ShipDate
               ,'Auto Sync'
               ,GETUTCDATE())

            SELECT @TimesheetId = SCOPE_IDENTITY();
        END

        -- Same route total calc as the driver loop -- one route earns one
        -- dollar amount that gets stamped onto every crew member's detail
        -- row for that route.
        SELECT @RouteTotal = ISNULL(SUM(SalesTotal), 0)
        FROM dbo.Sales
        WHERE ShipDate = @ShipDateOnly
          AND ShipRoute = @ShipRoute;

        -- Loader-specific marker: 'System Loader ($1,234.56)'. Distinct from
        -- the driver's 'Auto Sync $1,234.56' so the two job types are
        -- visually separable in the timesheet list, reports, and CSV export.
        SET @LoaderDetailNotes = 'System Loader (' + FORMAT(@RouteTotal, 'C', 'en-US') + ')';

        -- Dedup scoped to JobCode='L' so driver and loader details on the
        -- same route can coexist (happens when the same person both drives
        -- and loads, or when loader was already manually entered).
        IF NOT EXISTS (
            SELECT 1 FROM [dbo].[TimesheetDetail]
            WHERE TimesheetId = @TimesheetId
              AND JobCode = 'L'
              AND Route = @ShipRoute
        )
        BEGIN
            INSERT INTO [dbo].[TimesheetDetail]
               ([TimesheetId]
               ,[JobCode]
               ,[Qty]
               ,[JobRate]
               ,[ExtTotal]
               ,[Route]
               ,[Notes])
            VALUES
               (@TimesheetId
               ,'L'
               ,1
               ,@LoaderJobRate
               ,@LoaderJobRate
               ,@ShipRoute
               ,@LoaderDetailNotes)
        END

        SET @RowNum += 1
    END
END


GO
