
CREATE PROCEDURE [dbo].[Scheduler_ImportDriverTimesheet]
AS
BEGIN
    SET NOCOUNT ON;

    /*
      Daily scheduler (runs ~11am) — imports today's driver routes from
      SalesRoute into the driver's Timesheet for today.

      Behavior:
        1. One Timesheet per (Driver, today). If the driver already has a
           Timesheet for today (manual or prior auto-sync run), reuse it.
           Otherwise create a new one with Notes='Auto Sync'.
        2. Each imported route becomes a TimesheetDetail under that Timesheet
           with Notes='Auto Sync' so individual auto-imported rows are
           identifiable even when nested under a manual Timesheet.
        3. Idempotent — if a TimesheetDetail already exists for the same
           Timesheet + Route, skip it. Manual reruns won't duplicate.
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

    SELECT @CompanyTimezone = Timezone FROM Company
    SELECT @JobRate = JobRate FROM EmpJob WHERE JobCode = 'D'

    INSERT INTO @TimeTable
    SELECT s.ShipDate, s.ShipRoute, s.DriverId
    FROM SalesRoute AS s
    WHERE s.ShipDate = CONVERT(date, GETDATE()) AND s.Driver IS NOT NULL

    SELECT @MaxRow = COUNT(*) FROM @TimeTable

    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT @ShipDateOnly = ShipDate,
               @ShipRoute    = ShipRoute,
               @DriverId     = DriverId
        FROM @TimeTable WHERE Id = @RowNum

        -- Look for an existing Timesheet for (Driver, today). Match on the
        -- date part of InTime in local-time terms (InTime is stored UTC; the
        -- 9am-local logic below means a 'today' shift's InTime UTC date may
        -- differ from local date — but our scheduler always inserts using the
        -- same local-9am-to-UTC conversion, so matching on DATE-equivalent
        -- works for any Timesheet created by this same process. For manual
        -- Timesheets, the user may have entered a different time; we still
        -- match by date.)
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

        -- Insert the route as a TimesheetDetail, but only if one doesn't
        -- already exist for this Timesheet + Route. Dedup guard for reruns.
        IF NOT EXISTS (
            SELECT 1 FROM [dbo].[TimesheetDetail]
            WHERE TimesheetId = @TimesheetId
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
               ,'Auto Sync')
        END

        SET @RowNum += 1
    END
END

