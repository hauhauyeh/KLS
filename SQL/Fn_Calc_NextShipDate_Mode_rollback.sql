-- Roll back NEXT_SHIPDATE_MODE setting and restore original Fn_Calc_NextShipDate

DELETE FROM SystemSetting
WHERE SettingKey = 'NEXT_SHIPDATE_MODE';
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Fn_Calc_NextShipDate]
    @PayeeId   INT,
    @ShipDate  DATE OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @Now                 DATETIME,
        @ORDER_CHECKOUT_HOUR INT,
        @SYSTEM_WEEK_END     NVARCHAR(50),
        @CustSchedule        NVARCHAR(50),
        @TodayIdx            INT,
        @Idx                 INT,
        @Offset              INT,
        @CandidateDate       DATETIME;

    -- Current local datetime
    EXEC dbo.Get_TodayLocalDate @Now OUTPUT;

    -- Load system settings
    SELECT @ORDER_CHECKOUT_HOUR = TRY_CONVERT(INT, SettingValue)
    FROM SystemSetting
    WHERE SettingKey = 'ORDER_CHECKOUT_HOUR';

    SELECT @SYSTEM_WEEK_END = SettingValue
    FROM SystemSetting
    WHERE SettingKey = 'SYSTEM_WEEK_END';

    -- Load schedule; default to '123456' if NULL/blank
    SELECT @CustSchedule = LTRIM(RTRIM(ISNULL(CallSchedule, '')))
    FROM Customer
    WHERE PayeeId = @PayeeId;

    -- Normalize (remove spaces)
    SET @CustSchedule = REPLACE(@CustSchedule, ' ', '');

    -- If customer didn't set schedule, default to Mon-Sat
    IF @CustSchedule = ''
        SET @CustSchedule = '123456';

    -- Map weekday name to 0-6 index
    SET @TodayIdx =
        CASE DATENAME(WEEKDAY, @Now)
            WHEN 'Sunday'    THEN 0
            WHEN 'Monday'    THEN 1
            WHEN 'Tuesday'   THEN 2
            WHEN 'Wednesday' THEN 3
            WHEN 'Thursday'  THEN 4
            WHEN 'Friday'    THEN 5
            WHEN 'Saturday'  THEN 6
        END;

    -- If before cutoff and today is in schedule -> ship today
    IF DATEPART(HOUR, @Now) < @ORDER_CHECKOUT_HOUR
       AND CHARINDEX(CONVERT(CHAR(1), @TodayIdx), @CustSchedule) > 0
    BEGIN
        SET @ShipDate = CONVERT(DATE, @Now);
        RETURN;
    END

    -- Otherwise: find next scheduled shipping date after "now"
    SET @Offset = 1;
    SET @ShipDate = NULL;

    WHILE @Offset <= 14 AND @ShipDate IS NULL
    BEGIN
        SET @CandidateDate = DATEADD(DAY, @Offset, @Now);

        SET @Idx =
            CASE DATENAME(WEEKDAY, @CandidateDate)
                WHEN 'Sunday'    THEN 0
                WHEN 'Monday'    THEN 1
                WHEN 'Tuesday'   THEN 2
                WHEN 'Wednesday' THEN 3
                WHEN 'Thursday'  THEN 4
                WHEN 'Friday'    THEN 5
                WHEN 'Saturday'  THEN 6
            END;

        IF CHARINDEX(CONVERT(CHAR(1), @Idx), @CustSchedule) > 0
        BEGIN
            SET @ShipDate = CONVERT(DATE, @CandidateDate);
        END

        SET @Offset += 1;
    END
END
