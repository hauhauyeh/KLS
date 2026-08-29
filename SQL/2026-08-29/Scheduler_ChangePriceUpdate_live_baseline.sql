
CREATE   PROCEDURE [dbo].[Scheduler_ChangePriceUpdate]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today      DATE = CAST(GETDATE() AS DATE)
    DECLARE @NextDay    DATE = DATEADD(DAY,  1, @Today)
    DECLARE @PrevDay    DATE = DATEADD(DAY, -1, @Today)

    -- DayOfWeek: SQL DATEPART standard → 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    DECLARE @TodayDOW   INT = DATEPART(dw, @Today)
    DECLARE @NextDayDOW INT = DATEPART(dw, @NextDay)

    DECLARE @IsNextHoliday  INT
    DECLARE @IsPrevHoliday  INT
    DECLARE @IsNextNextHoliday INT  -- used to avoid premature undo
    DECLARE @CurrentDOW     INT
    DECLARE @OriginalDOW    INT

    SELECT @IsNextHoliday     = COUNT(*) FROM Holiday WHERE HolidayDate = @NextDay
    SELECT @IsPrevHoliday     = COUNT(*) FROM Holiday WHERE HolidayDate = @PrevDay
    SELECT @IsNextNextHoliday = COUNT(*) FROM Holiday WHERE HolidayDate = DATEADD(DAY, 1, @NextDay)

    -- =========================================================
    -- 1. TOMORROW IS A HOLIDAY → SHIFT FORWARD +1 DAY
    -- =========================================================
    IF @IsNextHoliday > 0
    BEGIN
        -- --- Update Item Prices (+ Update Price Flag moves together) ---
        SELECT @CurrentDOW = DayOfWeek, @OriginalDOW = OriginalDayOfWeek
        FROM SchedulerConfig WHERE JobName = 'Update Item Prices'

        IF @CurrentDOW = @NextDayDOW
        BEGIN
            UPDATE SchedulerConfig
            SET
                -- Save original only on the FIRST shift (OriginalDayOfWeek is still NULL)
                OriginalDayOfWeek = CASE WHEN OriginalDayOfWeek IS NULL THEN DayOfWeek ELSE OriginalDayOfWeek END,
                DayOfWeek = CASE WHEN DayOfWeek = 7 THEN 1 ELSE DayOfWeek + 1 END,
                UpdatedAt = GETDATE()
            WHERE JobName = 'Update Item Prices'

            -- Update Price Flag always moves together
            UPDATE SchedulerConfig
            SET
                OriginalDayOfWeek = CASE WHEN OriginalDayOfWeek IS NULL THEN DayOfWeek ELSE OriginalDayOfWeek END,
                DayOfWeek = CASE WHEN DayOfWeek = 7 THEN 1 ELSE DayOfWeek + 1 END,
                UpdatedAt = GETDATE()
            WHERE JobName = 'Update Price Flag'
        END

        -- --- Email Customer Price Sheet (independent) ---
        SELECT @CurrentDOW = DayOfWeek
        FROM SchedulerConfig WHERE JobName = 'Email Pricesheet'

        IF @CurrentDOW = @NextDayDOW
        BEGIN
            UPDATE SchedulerConfig
            SET
                OriginalDayOfWeek = CASE WHEN OriginalDayOfWeek IS NULL THEN DayOfWeek ELSE OriginalDayOfWeek END,
                DayOfWeek = CASE WHEN DayOfWeek = 7 THEN 1 ELSE DayOfWeek + 1 END,
                UpdatedAt = GETDATE()
            WHERE JobName = 'Email Pricesheet'
        END
    END

    -- =========================================================
    -- 2. YESTERDAY WAS A HOLIDAY → UNDO (only if today is NOT also a holiday
    --    AND tomorrow is NOT a holiday, meaning we are fully clear)
    -- =========================================================
    IF @IsPrevHoliday > 0 AND @IsNextHoliday = 0
    BEGIN
        -- --- Update Item Prices ---
        SELECT @CurrentDOW = DayOfWeek, @OriginalDOW = OriginalDayOfWeek
        FROM SchedulerConfig WHERE JobName = 'Update Item Prices'

        -- Only undo if we actually shifted (OriginalDayOfWeek is not NULL)
        IF @OriginalDOW IS NOT NULL AND @CurrentDOW = @TodayDOW
        BEGIN
            UPDATE SchedulerConfig
            SET DayOfWeek         = OriginalDayOfWeek,
                OriginalDayOfWeek = NULL,
                UpdatedAt         = GETDATE()
            WHERE JobName = 'Update Item Prices'

            -- Update Price Flag restores together
            UPDATE SchedulerConfig
            SET DayOfWeek         = OriginalDayOfWeek,
                OriginalDayOfWeek = NULL,
                UpdatedAt         = GETDATE()
            WHERE JobName = 'Update Price Flag'
        END

        -- --- Email Customer Price Sheet ---
        SELECT @CurrentDOW = DayOfWeek, @OriginalDOW = OriginalDayOfWeek
        FROM SchedulerConfig WHERE JobName = 'Email Pricesheet'

        IF @OriginalDOW IS NOT NULL AND @CurrentDOW = @TodayDOW
        BEGIN
            UPDATE SchedulerConfig
            SET DayOfWeek         = OriginalDayOfWeek,
                OriginalDayOfWeek = NULL,
                UpdatedAt         = GETDATE()
            WHERE JobName = 'Email Pricesheet'
        END
    END

END
