SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-08-29 DOW-FIX (plan-scheduler-dayofweek-fix-v1): normalise DOW, wrap 6->0, reset NextRunTime on shift/undo, retire Update Price Flag block
-- SchedulerConfig.DayOfWeek is stored by the UI / ERPScheduler in .NET convention: Sun=0 .. Sat=6.
--   SQL DATEPART(dw) depends on @@DATEFIRST (US default 7: Sun=1..Sat=7). Normalise with
--   (DATEPART(dw, d) + @@DATEFIRST - 1) % 7  ->  Sun=0 .. Sat=6 under ANY DATEFIRST:
--     DATEFIRST 7: Sun dw=1 -> (1+6)%7=0 | Mon 2 -> 1 | ... | Fri 6 -> 5 | Sat 7 -> (7+6)%7=6
--     DATEFIRST 1: Mon dw=1 -> (1+0)%7=1 | ... | Sat 6 -> 6 | Sun 7 -> 7%7=0
--   Before this fix the SQL side compared the raw DATEPART, so Saturday (6) displayed as Friday
--   and the schedule-day guard disagreed with the day the scheduler actually fires.
-- Baseline: Scheduler_ChangePriceUpdate_live_baseline.sql
CREATE OR ALTER PROCEDURE [dbo].[Scheduler_ChangePriceUpdate]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today      DATE = CAST(GETDATE() AS DATE)
    DECLARE @NextDay    DATE = DATEADD(DAY,  1, @Today)
    DECLARE @PrevDay    DATE = DATEADD(DAY, -1, @Today)

    -- 2026-08-29 DOW-FIX (plan-scheduler-dayofweek-fix-v1): DayOfWeek is stored Sun=0..Sat=6 (UI / ERPScheduler); normalise DATEPART.
    -- DECLARE @TodayDOW   INT = DATEPART(dw, @Today)      -- replaced (was 1=Sun..7=Sat)
    -- DECLARE @NextDayDOW INT = DATEPART(dw, @NextDay)    -- replaced
    DECLARE @TodayDOW   INT = (DATEPART(dw, @Today)   + @@DATEFIRST - 1) % 7
    DECLARE @NextDayDOW INT = (DATEPART(dw, @NextDay) + @@DATEFIRST - 1) % 7

    DECLARE @IsNextHoliday  INT
    DECLARE @IsPrevHoliday  INT
    DECLARE @IsNextNextHoliday INT  -- used to avoid premature undo
    DECLARE @CurrentDOW     INT
    DECLARE @OriginalDOW    INT

    SELECT @IsNextHoliday     = COUNT(*) FROM Holiday WHERE HolidayDate = @NextDay
    SELECT @IsPrevHoliday     = COUNT(*) FROM Holiday WHERE HolidayDate = @PrevDay
    SELECT @IsNextNextHoliday = COUNT(*) FROM Holiday WHERE HolidayDate = DATEADD(DAY, 1, @NextDay)

    -- =========================================================
    -- 1. TOMORROW IS A HOLIDAY -> SHIFT FORWARD +1 DAY
    -- =========================================================
    IF @IsNextHoliday > 0
    BEGIN
        -- --- Update Item Prices ---
        SELECT @CurrentDOW = DayOfWeek, @OriginalDOW = OriginalDayOfWeek
        FROM SchedulerConfig WHERE JobName = 'Update Item Prices'

        IF @CurrentDOW = @NextDayDOW
        BEGIN
            UPDATE SchedulerConfig
            SET
                -- Save original only on the FIRST shift (OriginalDayOfWeek is still NULL)
                OriginalDayOfWeek = CASE WHEN OriginalDayOfWeek IS NULL THEN DayOfWeek ELSE OriginalDayOfWeek END,
                DayOfWeek = CASE WHEN DayOfWeek = 6 THEN 0 ELSE DayOfWeek + 1 END,   -- DOW-FIX: wrap Sat(6)->Sun(0)
                UpdatedAt = GETDATE(),
                NextRunTime = NULL   -- DOW-FIX: ERPScheduler uses NextRunTime when set; NULL forces recompute from the new DayOfWeek
            WHERE JobName = 'Update Item Prices'

            -- DOW-FIX 2026-08-29: 'Update Price Flag' job row was deleted; block kept for history.
--             -- Update Price Flag always moves together
--             UPDATE SchedulerConfig
--             SET
--                 OriginalDayOfWeek = CASE WHEN OriginalDayOfWeek IS NULL THEN DayOfWeek ELSE OriginalDayOfWeek END,
--                 DayOfWeek = CASE WHEN DayOfWeek = 6 THEN 0 ELSE DayOfWeek + 1 END,   -- DOW-FIX: wrap Sat(6)->Sun(0)
--                 UpdatedAt = GETDATE()
--             WHERE JobName = 'Update Price Flag'
        END

        -- --- Email Customer Price Sheet (independent) ---
        SELECT @CurrentDOW = DayOfWeek
        FROM SchedulerConfig WHERE JobName = 'Email Pricesheet'

        IF @CurrentDOW = @NextDayDOW
        BEGIN
            UPDATE SchedulerConfig
            SET
                OriginalDayOfWeek = CASE WHEN OriginalDayOfWeek IS NULL THEN DayOfWeek ELSE OriginalDayOfWeek END,
                DayOfWeek = CASE WHEN DayOfWeek = 6 THEN 0 ELSE DayOfWeek + 1 END,   -- DOW-FIX: wrap Sat(6)->Sun(0)
                UpdatedAt = GETDATE(),
                NextRunTime = NULL   -- DOW-FIX: ERPScheduler uses NextRunTime when set; NULL forces recompute from the new DayOfWeek
            WHERE JobName = 'Email Pricesheet'
        END
    END

    -- =========================================================
    -- 2. YESTERDAY WAS A HOLIDAY -> UNDO (only if today is NOT also a holiday
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
                UpdatedAt         = GETDATE(),
                NextRunTime = NULL   -- DOW-FIX: ERPScheduler uses NextRunTime when set; NULL forces recompute from the new DayOfWeek
            WHERE JobName = 'Update Item Prices'

            -- DOW-FIX 2026-08-29: 'Update Price Flag' job row was deleted; block kept for history.
--             -- Update Price Flag restores together
--             UPDATE SchedulerConfig
--             SET DayOfWeek         = OriginalDayOfWeek,
--                 OriginalDayOfWeek = NULL,
--                 UpdatedAt         = GETDATE()
--             WHERE JobName = 'Update Price Flag'
        END

        -- --- Email Customer Price Sheet ---
        SELECT @CurrentDOW = DayOfWeek, @OriginalDOW = OriginalDayOfWeek
        FROM SchedulerConfig WHERE JobName = 'Email Pricesheet'

        IF @OriginalDOW IS NOT NULL AND @CurrentDOW = @TodayDOW
        BEGIN
            UPDATE SchedulerConfig
            SET DayOfWeek         = OriginalDayOfWeek,
                OriginalDayOfWeek = NULL,
                UpdatedAt         = GETDATE(),
                NextRunTime = NULL   -- DOW-FIX: ERPScheduler uses NextRunTime when set; NULL forces recompute from the new DayOfWeek
            WHERE JobName = 'Email Pricesheet'
        END
    END

END

GO
