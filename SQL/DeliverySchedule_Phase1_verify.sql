DECLARE @WeeklyPayeeId INT;
DECLARE @ShipDate DATE;
DECLARE @Now DATETIME;
DECLARE @Today DATE;
DECLARE @Tomorrow DATE;
DECLARE @DayAfterTomorrow DATE;
DECLARE @TomorrowIdx INT;
DECLARE @ExpectedMonthlyDay INT;

SELECT TOP 1 @WeeklyPayeeId = c.PayeeId
FROM dbo.Customer c
WHERE LTRIM(RTRIM(ISNULL(c.CallSchedule, ''))) = '14'
ORDER BY c.PayeeId;

IF @WeeklyPayeeId IS NULL
BEGIN
    RAISERROR('Verification precheck failed: no customer with CallSchedule = 14 was found.', 16, 1);
    RETURN;
END

EXEC dbo.Get_TodayLocalDate @Now OUTPUT;

SET @Today = CONVERT(DATE, @Now);
SET @Tomorrow = DATEADD(DAY, 1, @Today);
SET @DayAfterTomorrow = DATEADD(DAY, 2, @Today);
SET @ExpectedMonthlyDay = DAY(@DayAfterTomorrow);

SET @TomorrowIdx =
    CASE DATENAME(WEEKDAY, @Tomorrow)
        WHEN 'Sunday'    THEN 0
        WHEN 'Monday'    THEN 1
        WHEN 'Tuesday'   THEN 2
        WHEN 'Wednesday' THEN 3
        WHEN 'Thursday'  THEN 4
        WHEN 'Friday'    THEN 5
        WHEN 'Saturday'  THEN 6
    END;

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.SystemSetting
    SET SettingValue = 'CUSTOMER'
    WHERE SettingKey = 'NEXT_SHIPDATE_MODE';

    EXEC dbo.Fn_Calc_NextShipDate @WeeklyPayeeId, @ShipDate OUTPUT;

    SELECT
        'WeeklyFallback' AS TestName,
        @WeeklyPayeeId AS PayeeId,
        @ShipDate AS ShipDate,
        DATENAME(WEEKDAY, @ShipDate) AS ShipWeekday;

    INSERT INTO dbo.DeliverSchedule
    (
        PayeeId,
        ScheduleType,
        StartDate,
        EndDate,
        WeekInterval,
        DayOfWeek,
        IsActive,
        Notes
    )
    VALUES
    (
        @WeeklyPayeeId,
        'BiWeekly',
        @Tomorrow,
        NULL,
        2,
        @TomorrowIdx,
        1,
        'Phase1 verification'
    );

    SET @ShipDate = NULL;
    EXEC dbo.Fn_Calc_NextShipDate @WeeklyPayeeId, @ShipDate OUTPUT;

    SELECT
        'BiWeeklyOverride' AS TestName,
        @WeeklyPayeeId AS PayeeId,
        @Tomorrow AS ExpectedShipDate,
        @ShipDate AS ActualShipDate,
        CASE WHEN @ShipDate = @Tomorrow THEN 'PASS' ELSE 'FAIL' END AS Result;

    DELETE FROM dbo.DeliverSchedule
    WHERE PayeeId = @WeeklyPayeeId
      AND Notes = 'Phase1 verification';

    INSERT INTO dbo.DeliverSchedule
    (
        PayeeId,
        ScheduleType,
        StartDate,
        EndDate,
        DayOfMonth,
        IsActive,
        Notes
    )
    VALUES
    (
        @WeeklyPayeeId,
        'Monthly',
        @Today,
        NULL,
        @ExpectedMonthlyDay,
        1,
        'Phase1 verification'
    );

    SET @ShipDate = NULL;
    EXEC dbo.Fn_Calc_NextShipDate @WeeklyPayeeId, @ShipDate OUTPUT;

    SELECT
        'MonthlyOverride' AS TestName,
        @WeeklyPayeeId AS PayeeId,
        @DayAfterTomorrow AS ExpectedShipDate,
        @ShipDate AS ActualShipDate,
        CASE WHEN @ShipDate = @DayAfterTomorrow THEN 'PASS' ELSE 'FAIL' END AS Result;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH
GO
