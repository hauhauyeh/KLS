DECLARE @WeeklyPayeeId INT;
DECLARE @ShipDate DATE;
DECLARE @Now DATETIME;
DECLARE @Today DATE;
DECLARE @Tomorrow DATE;
DECLARE @DayAfterTomorrow DATE;
DECLARE @TomorrowIdx INT;
DECLARE @ExpectedMonthlyDay INT;
DECLARE @FutureMonthlyStart DATE;

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
SET @FutureMonthlyStart = DATEADD(DAY, 10, @Today);

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
        'Phase1 fix verification'
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
      AND Notes = 'Phase1 fix verification';

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
        'Phase1 fix verification'
    );

    SET @ShipDate = NULL;
    EXEC dbo.Fn_Calc_NextShipDate @WeeklyPayeeId, @ShipDate OUTPUT;

    SELECT
        'MonthlyOverride' AS TestName,
        @WeeklyPayeeId AS PayeeId,
        @DayAfterTomorrow AS ExpectedShipDate,
        @ShipDate AS ActualShipDate,
        CASE WHEN @ShipDate = @DayAfterTomorrow THEN 'PASS' ELSE 'FAIL' END AS Result;

    DELETE FROM dbo.DeliverSchedule
    WHERE PayeeId = @WeeklyPayeeId
      AND Notes = 'Phase1 fix verification';

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
        @FutureMonthlyStart,
        NULL,
        DAY(@Today),
        1,
        'Phase1 fix verification'
    );

    SET @ShipDate = NULL;
    EXEC dbo.Fn_Calc_NextShipDate @WeeklyPayeeId, @ShipDate OUTPUT;

    SELECT
        'MonthlyStartDateGuard' AS TestName,
        @WeeklyPayeeId AS PayeeId,
        @FutureMonthlyStart AS ExpectedEarliestDate,
        @ShipDate AS ActualShipDate,
        CASE WHEN @ShipDate >= @FutureMonthlyStart THEN 'PASS' ELSE 'FAIL' END AS Result;

    DELETE FROM dbo.DeliverSchedule
    WHERE PayeeId = @WeeklyPayeeId
      AND Notes = 'Phase1 fix verification';

    BEGIN TRY
        INSERT INTO dbo.DeliverSchedule
        (
            PayeeId,
            ScheduleType,
            StartDate,
            EndDate,
            IsActive,
            Notes
        )
        VALUES
        (
            @WeeklyPayeeId,
            'Monthly',
            @Today,
            NULL,
            1,
            'Invalid shape test'
        );

        SELECT 'InvalidShapeConstraint' AS TestName, 'FAIL' AS Result;
    END TRY
    BEGIN CATCH
        SELECT 'InvalidShapeConstraint' AS TestName, 'PASS' AS Result, ERROR_MESSAGE() AS Message;
    END CATCH

    BEGIN TRY
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
            @Today,
            NULL,
            2,
            @TomorrowIdx,
            1,
            'Duplicate active test 1'
        );

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
            'Duplicate active test 2'
        );

        SELECT 'DuplicateActiveConstraint' AS TestName, 'FAIL' AS Result;
    END TRY
    BEGIN CATCH
        SELECT 'DuplicateActiveConstraint' AS TestName, 'PASS' AS Result, ERROR_MESSAGE() AS Message;
    END CATCH

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH
GO
