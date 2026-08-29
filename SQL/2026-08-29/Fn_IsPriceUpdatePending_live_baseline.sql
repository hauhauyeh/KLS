-- 2026-08-29 plan-reprice-open-orders-v1 slice 2 (D2=B).
-- Returns 1 when an order posted right now should be flagged IsPricePending:
--   today is the 'Update Item Prices' schedule day (SchedulerConfig.DayOfWeek, which
--   Scheduler_ChangePriceUpdate already shifts on holidays) and the weekly cost apply
--   has not run yet today (no live ItemCostApply row for today) and it is before the job's RunTime.
-- Same rule as Item_PendingCostStatus. TOTAL FUNCTION: any missing/NULL config -> 0, never throws
-- (it is called inside Sales_Insert; a throw here would block every order post - risk R2).
-- SELECT dbo.Fn_IsPriceUpdatePending()
CREATE   FUNCTION [dbo].[Fn_IsPriceUpdatePending]()
RETURNS BIT
AS
BEGIN
    DECLARE @Today     DATE = CAST(GETDATE() AS DATE);
    DECLARE @DayOfWeek TINYINT;
    DECLARE @IsEnabled BIT;
    DECLARE @RunTime   TIME;

    SELECT TOP (1) @DayOfWeek = DayOfWeek, @IsEnabled = IsEnabled, @RunTime = RunTime
    FROM dbo.SchedulerConfig
    WHERE JobName = 'Update Item Prices';

    IF @DayOfWeek IS NULL OR ISNULL(@IsEnabled, 0) = 0
        RETURN 0;

    IF DATEPART(dw, @Today) <> @DayOfWeek
        RETURN 0;

    -- Window closes at the schedule time (same as MGP): after RunTime the job has run or
    -- skipped ("nothing pending" writes no ItemCostApply row), so later orders must not be
    -- flagged - otherwise nothing would ever reprice/unflag them until next week.
    IF @RunTime IS NOT NULL AND CAST(GETDATE() AS TIME) >= @RunTime
        RETURN 0;

    IF EXISTS (SELECT 1 FROM dbo.ItemCostApply WHERE ScheduleDate = @Today AND UndoneAt IS NULL)
        RETURN 0;

    RETURN 1;
END
