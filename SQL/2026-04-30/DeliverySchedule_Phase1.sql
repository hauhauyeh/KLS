SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.DeliverSchedule', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[DeliverSchedule]
    (
        [DeliverScheduleId] INT IDENTITY(1,1) NOT NULL,
        [PayeeId] INT NOT NULL,
        [ScheduleType] NVARCHAR(30) NOT NULL,
        [StartDate] DATE NULL,
        [EndDate] DATE NULL,
        [WeekInterval] INT NULL,
        [DayOfWeek] INT NULL,
        [WeekOfMonth] INT NULL,
        [DayOfMonth] INT NULL,
        [IsActive] BIT NOT NULL CONSTRAINT [DF_DeliverSchedule_IsActive] DEFAULT ((1)),
        [Notes] NVARCHAR(300) NULL,
        [CreatedAt] DATETIME NULL,
        [UpdatedAt] DATETIME NULL,
        [EnterBy] NVARCHAR(50) NULL,
        [UpdateBy] NVARCHAR(50) NULL,
        CONSTRAINT [PK_DeliverSchedule] PRIMARY KEY CLUSTERED ([DeliverScheduleId] ASC),
        CONSTRAINT [FK_DeliverSchedule_Payee] FOREIGN KEY ([PayeeId]) REFERENCES [dbo].[Payee]([PayeeId]),
        CONSTRAINT [CK_DeliverSchedule_ScheduleType] CHECK ([ScheduleType] IN ('BiWeekly', 'Monthly')),
        CONSTRAINT [CK_DeliverSchedule_DayOfWeek] CHECK ([DayOfWeek] IS NULL OR [DayOfWeek] BETWEEN 0 AND 6),
        CONSTRAINT [CK_DeliverSchedule_WeekInterval] CHECK ([WeekInterval] IS NULL OR [WeekInterval] = 2),
        CONSTRAINT [CK_DeliverSchedule_WeekOfMonth] CHECK ([WeekOfMonth] IS NULL OR [WeekOfMonth] BETWEEN 1 AND 5),
        CONSTRAINT [CK_DeliverSchedule_DayOfMonth] CHECK ([DayOfMonth] IS NULL OR [DayOfMonth] BETWEEN 1 AND 31),
        CONSTRAINT [CK_DeliverSchedule_TypeShape] CHECK (
            ([ScheduleType] = 'BiWeekly'
                AND [StartDate] IS NOT NULL
                AND [DayOfWeek] IS NOT NULL
                AND [WeekInterval] = 2
                AND [WeekOfMonth] IS NULL
                AND [DayOfMonth] IS NULL)
            OR
            ([ScheduleType] = 'Monthly'
                AND (
                    ([DayOfMonth] IS NOT NULL AND [WeekOfMonth] IS NULL AND [DayOfWeek] IS NULL AND [WeekInterval] IS NULL)
                    OR
                    ([DayOfMonth] IS NULL AND [WeekOfMonth] IS NOT NULL AND [DayOfWeek] IS NOT NULL AND [WeekInterval] IS NULL)
                ))
        )
    );
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.DeliverSchedule')
      AND name = 'UX_DeliverSchedule_ActivePayee'
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [UX_DeliverSchedule_ActivePayee]
        ON [dbo].[DeliverSchedule] ([PayeeId])
        WHERE [IsActive] = 1;
END
GO

IF OBJECT_ID('dbo.Fn_Calc_NextShipDate_prev', 'P') IS NULL
   AND OBJECT_ID('dbo.Fn_Calc_NextShipDate', 'P') IS NOT NULL
BEGIN
    EXEC sp_rename 'dbo.Fn_Calc_NextShipDate', 'Fn_Calc_NextShipDate_prev';
END
GO

IF OBJECT_ID('dbo.Fn_Calc_NextShipDate', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE [dbo].[Fn_Calc_NextShipDate];
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Fn_Calc_NextShipDate]
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
        @CandidateDate       DATE,
        @AdvScheduleType     NVARCHAR(30),
        @AdvStartDate        DATE,
        @AdvEndDate          DATE,
        @AdvWeekInterval     INT,
        @AdvDayOfWeek        INT,
        @AdvWeekOfMonth      INT,
        @AdvDayOfMonth       INT,
        @CandidateWeekNum    INT,
        @CandidateWeekOfMonth INT,
        @CandidateDaysInMonth INT;

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
        SELECT TOP 1
            @AdvScheduleType = ds.ScheduleType,
            @AdvStartDate = ds.StartDate,
            @AdvEndDate = ds.EndDate,
            @AdvWeekInterval = ds.WeekInterval,
            @AdvDayOfWeek = ds.DayOfWeek,
            @AdvWeekOfMonth = ds.WeekOfMonth,
            @AdvDayOfMonth = ds.DayOfMonth
        FROM dbo.DeliverSchedule ds
        WHERE ds.PayeeId = @PayeeId
          AND ds.IsActive = 1
          AND ds.ScheduleType IN ('BiWeekly', 'Monthly')
        ORDER BY ds.DeliverScheduleId DESC;

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
        -- Normal mode ignores customer-specific schedules and uses default Mon-Sat.
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

    IF @NEXT_SHIPDATE_MODE = 'CUSTOMER'
       AND @AdvScheduleType IS NOT NULL
    BEGIN
        IF @AdvScheduleType = 'BiWeekly'
           AND @AdvDayOfWeek IS NOT NULL
           AND @AdvStartDate IS NOT NULL
        BEGIN
            SET @Offset = 0;
            SET @ShipDate = NULL;

            WHILE @Offset <= 21 AND @ShipDate IS NULL
            BEGIN
                SET @CandidateDate = DATEADD(DAY, @Offset, CONVERT(DATE, @Now));
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

                IF @Idx = @AdvDayOfWeek
                   AND @CandidateDate >= @AdvStartDate
                   AND (@AdvEndDate IS NULL OR @CandidateDate <= @AdvEndDate)
                BEGIN
                    SET @CandidateWeekNum = DATEDIFF(DAY, @AdvStartDate, @CandidateDate) / 7;

                    IF @CandidateWeekNum >= 0
                       AND @CandidateWeekNum % ISNULL(NULLIF(@AdvWeekInterval, 0), 2) = 0
                       AND (
                            @Offset > 0
                            OR (
                                DATEPART(HOUR, @Now) < ISNULL(@ORDER_CHECKOUT_HOUR, 10)
                                AND @TodayIdx = @AdvDayOfWeek
                            )
                       )
                    BEGIN
                        SET @ShipDate = @CandidateDate;
                    END
                END

                SET @Offset += 1;
            END
        END
        ELSE IF @AdvScheduleType = 'Monthly'
                AND (
                    @AdvDayOfMonth IS NOT NULL
                    OR (@AdvWeekOfMonth IS NOT NULL AND @AdvDayOfWeek IS NOT NULL)
                )
        BEGIN
            SET @Offset = 0;
            SET @ShipDate = NULL;

            WHILE @Offset <= 62 AND @ShipDate IS NULL
            BEGIN
                SET @CandidateDate = DATEADD(DAY, @Offset, CONVERT(DATE, @Now));
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

                SET @CandidateDaysInMonth = DAY(EOMONTH(@CandidateDate));
                SET @CandidateWeekOfMonth = ((DAY(@CandidateDate) - 1) / 7) + 1;

                IF (@AdvStartDate IS NULL OR @CandidateDate >= @AdvStartDate)
                   AND (@AdvEndDate IS NULL OR @CandidateDate <= @AdvEndDate)
                   AND (
                        (@AdvDayOfMonth IS NOT NULL AND DAY(@CandidateDate) = @AdvDayOfMonth)
                        OR (
                            @AdvWeekOfMonth IS NOT NULL
                            AND @AdvDayOfWeek IS NOT NULL
                            AND @Idx = @AdvDayOfWeek
                            AND (
                                @CandidateWeekOfMonth = @AdvWeekOfMonth
                                OR (
                                    @AdvWeekOfMonth = 5
                                    AND @CandidateWeekOfMonth >= 4
                                    AND DAY(@CandidateDate) + 7 > @CandidateDaysInMonth
                                )
                            )
                        )
                   )
                   AND (
                        @Offset > 0
                        OR DATEPART(HOUR, @Now) < ISNULL(@ORDER_CHECKOUT_HOUR, 10)
                   )
                BEGIN
                    SET @ShipDate = @CandidateDate;
                END

                SET @Offset += 1;
            END
        END

        IF @ShipDate IS NOT NULL
            RETURN;
    END

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
        SET @CandidateDate = DATEADD(DAY, @Offset, CONVERT(DATE, @Now));

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
            SET @ShipDate = @CandidateDate;
        END

        SET @Offset += 1;
    END
END
GO
