SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Scheduler_ImportDriverTimesheet];
GO

CREATE PROCEDURE [dbo].[Scheduler_ImportDriverTimesheet]   -- EXEC Scheduler_ImportDriverTimesheet
-- EXEC Scheduler_ImportDriverTimesheet @TargetDate='2026-05-22'   -- back-day re-sync
    @TargetDate DATE = NULL   -- defaults to today; admin overrides for back-day re-sync
AS
BEGIN
    SET NOCOUNT ON;

    /*
      Daily scheduler — imports a target date's driver AND loader assignments
      from SalesRoute into each crew member's Timesheet for that date.

      DAILY OPERATION (2026-05-27 rework):
        Cron runs daily at 6pm with no parameter -- defaults to today.
        At 6pm the driver/loader assignments for the day are settled, so the
        scheduler reliably catches everything that was assigned during the day.

      BACK-DAY RE-SYNC (manual):
        EXEC Scheduler_ImportDriverTimesheet @TargetDate='2026-05-22'
        Same logic, scoped to the supplied date. Safe to invoke repeatedly --
        system-level dedup (see below) prevents intra-system duplicates
        regardless of how many times this proc is run for the same date.

      DUPLICATE POLICY (manual + system coexist; system + system prevented):
        Manual entries (Timesheet_Insert path) and system entries (this SP)
        may coexist on the same Timesheet. System rows are tagged via Notes:
          Driver: 'Auto Sync $X,XXX.XX'
          Loader: 'System Loader ($X,XXX.XX)'
        Manual rows have user-typed Notes (often NULL). The reviewer deletes
        manual-vs-system duplicates during payroll close.

      SYSTEM-LEVEL IDEMPOTENT, per (PayeeId, ShipDate, JobCode, Route):
        Dedup is scoped to system-tagged rows only via Notes LIKE pattern,
        AND looks across ALL Timesheet headers for that (PayeeId, ShipDate)
        -- not just the one TimesheetId this proc happened to pick. Running
        the SP twice for the same date inserts ZERO duplicate system rows.

      HEADER SELECTION (NOT enforcement):
        For each crew member's target date, the SP reuses the same-day
        header selected by TOP 1 ORDER BY TimesheetId when one or more exist,
        else creates a fresh 9am-local header. Multiple headers for the same
        (PayeeId, ShipDate) are NOT prevented -- the cross-header dedup above
        handles that case correctly regardless.

      Source filter (both loops):
        - SalesRoute.DriverId / .LoaderId IS NOT NULL (the real FK; the
          text columns are denormalized display caches).
        - Route NOT IN ('P', 'CM') -- these route codes are scheduling
          artifacts that should never produce a crew timesheet entry.
    */

    -- 2026-05-27: default to today when no explicit @TargetDate supplied.
    -- Production cron job runs unparameterized.
    IF @TargetDate IS NULL
        SET @TargetDate = CONVERT(DATE, GETDATE());

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

    -- 2026-05-27: scoped by @TargetDate (defaults to today via the param block above).
    -- Source filter: real FK + exclude non-driver scheduling codes.
    INSERT INTO @TimeTable
    SELECT s.ShipDate, s.ShipRoute, s.DriverId
    FROM SalesRoute AS s
    WHERE s.ShipDate = @TargetDate
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

        -- No existing Timesheet → create one (with Notes='Auto Sync' since
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

        -- Compute route's Sales total — same calc as Report_JobSummary's
        -- RouteTotal column.
        SELECT @RouteTotal = ISNULL(SUM(SalesTotal), 0)
        FROM dbo.Sales
        WHERE ShipDate = @ShipDateOnly
          AND ShipRoute = @ShipRoute;

        -- Build the marker + formatted dollar amount: 'Auto Sync $1,234.56'.
        SET @DetailNotes = 'Auto Sync ' + FORMAT(@RouteTotal, 'C', 'en-US');

        -- 2026-05-27: system-level idempotent dedup. Insert the system row
        -- only if no SYSTEM row already exists for this (Driver, ShipDate,
        -- 'D', Route). Cross-header: looks across ALL same-day headers for
        -- this driver, not just the one @TimesheetId we picked. Manual rows
        -- (NULL or user-typed Notes) do NOT block -- they're business-rule
        -- duplicates that the reviewer cleans up during payroll close.
        IF NOT EXISTS (
            SELECT 1
            FROM   [dbo].[TimesheetDetail] td
            INNER JOIN [dbo].[Timesheet]   t ON t.TimesheetId = td.TimesheetId
            WHERE  t.PayeeId   = @DriverId
              AND  CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @CompanyTimezone AS DATE) = @ShipDateOnly
              AND  td.JobCode  = 'D'
              AND  td.Route    = @ShipRoute
              AND  td.Notes LIKE 'Auto Sync $%'
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

    -- 2026-05-27: scoped by @TargetDate (defaults to today via the param block above).
    INSERT INTO @LoaderTable
    SELECT s.ShipDate, s.ShipRoute, s.LoaderId
    FROM SalesRoute AS s
    WHERE s.ShipDate = @TargetDate
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

        -- 2026-05-27: system-level idempotent dedup. Same pattern as the
        -- driver loop -- only an existing SYSTEM row (Notes matches the
        -- 'System Loader (' format) blocks the insert, and the check looks
        -- across ALL same-day headers for this loader. Manual rows do NOT
        -- block -- reviewer handles manual-vs-system cleanup at payroll close.
        IF NOT EXISTS (
            SELECT 1
            FROM   [dbo].[TimesheetDetail] td
            INNER JOIN [dbo].[Timesheet]   t ON t.TimesheetId = td.TimesheetId
            WHERE  t.PayeeId   = @LoaderId
              AND  CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @CompanyTimezone AS DATE) = @ShipDateOnly
              AND  td.JobCode  = 'L'
              AND  td.Route    = @ShipRoute
              AND  td.Notes LIKE 'System Loader (%'
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
