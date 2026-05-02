-- Add NEXT_SHIPDATE_MODE setting and update Fn_Calc_NextShipDate
-- Modes:
--   CUSTOMER = use Customer.CallSchedule (current behavior)
--   NORMAL   = use default Mon-Sat shipping schedule

IF NOT EXISTS (SELECT 1 FROM SystemSetting WHERE SettingKey = 'NEXT_SHIPDATE_MODE')
BEGIN
    INSERT INTO SystemSetting (SettingKey, SettingValue, DataType, Description)
    VALUES ('NEXT_SHIPDATE_MODE', 'CUSTOMER', 'string', 'CUSTOMER = use Customer.CallSchedule, NORMAL = use default Mon-Sat next ship date');
END
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
        @NEXT_SHIPDATE_MODE  NVARCHAR(50),
        @CustSchedule        NVARCHAR(50),
        @WorkSchedule        NVARCHAR(50),
        @TodayIdx            INT,
        @Idx                 INT,
        @Offset              INT,
        @CandidateDate       DATETIME;

    EXEC dbo.Get_TodayLocalDate @Now OUTPUT;

    SELECT @ORDER_CHECKOUT_HOUR = TRY_CONVERT(INT, SettingValue)
    FROM SystemSetting
    WHERE SettingKey = 'ORDER_CHECKOUT_HOUR';

    SELECT @NEXT_SHIPDATE_MODE = UPPER(LTRIM(RTRIM(ISNULL(SettingValue, 'CUSTOMER'))))
    FROM SystemSetting
    WHERE SettingKey = 'NEXT_SHIPDATE_MODE';

    IF ISNULL(@NEXT_SHIPDATE_MODE, '') = ''
        SET @NEXT_SHIPDATE_MODE = 'CUSTOMER';

    IF @NEXT_SHIPDATE_MODE = 'CUSTOMER'
    BEGIN
        SELECT @CustSchedule = LTRIM(RTRIM(ISNULL(CallSchedule, '')))
        FROM Customer
        WHERE PayeeId = @PayeeId;

        SET @CustSchedule = REPLACE(ISNULL(@CustSchedule, ''), ' ', '');

        IF @CustSchedule = ''
            SET @WorkSchedule = '123456';
        ELSE
            SET @WorkSchedule = @CustSchedule;
    END
    ELSE
    BEGIN
        -- Normal mode ignores customer call schedule and uses default Mon-Sat.
        SET @WorkSchedule = '123456';
    END

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

    IF DATEPART(HOUR, @Now) < ISNULL(@ORDER_CHECKOUT_HOUR, 10)
       AND CHARINDEX(CONVERT(CHAR(1), @TodayIdx), @WorkSchedule) > 0
    BEGIN
        SET @ShipDate = CONVERT(DATE, @Now);
        RETURN;
    END

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

        IF CHARINDEX(CONVERT(CHAR(1), @Idx), @WorkSchedule) > 0
        BEGIN
            SET @ShipDate = CONVERT(DATE, @CandidateDate);
        END

        SET @Offset += 1;
    END
END
