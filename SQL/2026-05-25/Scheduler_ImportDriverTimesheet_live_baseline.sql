/*
    Scheduler_ImportDriverTimesheet_live_baseline.sql
    Captured 2026-05-25 from dev (COGENT-2024\SQLEXPRESS / KLS_2026).
    Frozen snapshot before the Phase 2 Loader-loop addition.
    DO NOT EDIT -- baseline only.
*/

CREATE PROCEDURE [dbo].[Scheduler_ImportDriverTimesheet]
AS
BEGIN
    SET NOCOUNT ON;

    /*
      Daily scheduler (runs ~11am) â€” imports today's driver routes from
      SalesRoute into the driver's Timesheet for today.

      Behavior:
        1. One Timesheet per (Driver, today). If the driver already has a
           Timesheet for today (manual or prior auto-sync run), reuse it.
           Otherwise create a new one with Notes='Auto Sync'.
        2. Each imported route becomes a TimesheetDetail under that Timesheet
           with Notes='Auto Sync $1,234.56' where the dollar amount is the
           route's total Sales for that ShipDate+ShipRoute (same calc as
           Report_JobSummary's RouteTotal column).
        3. Idempotent â€” duplicate guard is scoped to (TimesheetId, JobCode='D',
           Route). A Driver row and a Loader row on the same route are
           different jobs; both can coexist. The earlier coarse (TimesheetId,
           Route) guard silently swallowed the Driver insert when a Loader
           detail already existed on the same route (e.g. Alexis on every
           route, Abdel as Loader on his own driving route).

      Source filter:
        - SalesRoute.DriverId IS NOT NULL (the real FK; Driver is just a
          display-name string and can be stale/mismatched without a real
          driver assignment).
        - Route NOT IN ('P', 'CM') â€” these route codes are scheduling artifacts
          that should never produce a driver timesheet entry.
    */

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
    DECLARE @CompanyTimezone NVARCHAR(100)
    DECLARE @RouteTotal DECIMAL(18,2)
    DECLARE @DetailNotes NVARCHAR(200)

    SELECT @CompanyTimezone = Timezone FROM Company
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

        -- No existing Timesheet â†’ create one (with Notes='Auto Sync' since
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

        -- Compute route's Sales total â€” same calc as Report_JobSummary's
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
END
