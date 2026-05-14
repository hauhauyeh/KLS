-- One-time script: Insert driver timesheet for PayeeId 100152
-- Dates: May 6, 7, 8, 9, 11, 12 2026
SET NOCOUNT ON;

DECLARE @PayeeId INT = 100152
DECLARE @JobRate DECIMAL(18,2)
DECLARE @CompanyTimezone NVARCHAR(100)

SELECT @CompanyTimezone = Timezone FROM Company
SELECT @JobRate = JobRate FROM EmpJob WHERE JobCode = 'D'

DECLARE @Dates TABLE (ShipDate DATE)
INSERT INTO @Dates VALUES
    ('2026-05-06'),('2026-05-07'),('2026-05-08'),
    ('2026-05-09'),('2026-05-11'),('2026-05-12')

DECLARE @ShipDate DATE
DECLARE @InTimeUtc DATETIME
DECLARE @TimesheetNumber INT
DECLARE @TimesheetId INT
DECLARE @ShipRoute NVARCHAR(10)

DECLARE date_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT d.ShipDate, s.ShipRoute
    FROM @Dates d
    LEFT JOIN SalesRoute s ON s.ShipDate = d.ShipDate AND s.DriverId = @PayeeId
ORDER BY d.ShipDate

OPEN date_cursor
FETCH NEXT FROM date_cursor INTO @ShipDate, @ShipRoute

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @TimesheetNumber = NEXT VALUE FOR dbo.Seq_TimesheetNumber;

    -- Convert 9:00 AM local to UTC
    SET @InTimeUtc = (SELECT CAST(@ShipDate AS DATETIME) + '09:00:00'
        AT TIME ZONE @CompanyTimezone AT TIME ZONE 'UTC')

    INSERT INTO [dbo].[Timesheet]
       ([TimesheetNumber],[PayeeId],[InTime],[CreatedAt])
    VALUES
       (@TimesheetNumber, @PayeeId, @InTimeUtc, GETUTCDATE())

    SET @TimesheetId = SCOPE_IDENTITY();

    INSERT INTO [dbo].[TimesheetDetail]
       ([TimesheetId],[JobCode],[Qty],[JobRate],[ExtTotal],[Route])
    VALUES
       (@TimesheetId, 'D', 1, @JobRate, @JobRate, @ShipRoute)

    FETCH NEXT FROM date_cursor INTO @ShipDate, @ShipRoute
END

CLOSE date_cursor
DEALLOCATE date_cursor

PRINT 'Inserted 6 timesheet records for PayeeId 100152'
