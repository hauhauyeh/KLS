SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-08-29 DOW-FIX (plan-scheduler-dayofweek-fix-v1): normalise @TodayDow to Sun=0..Sat=6
-- SchedulerConfig.DayOfWeek is stored by the UI / ERPScheduler in .NET convention: Sun=0 .. Sat=6.
--   SQL DATEPART(dw) depends on @@DATEFIRST (US default 7: Sun=1..Sat=7). Normalise with
--   (DATEPART(dw, d) + @@DATEFIRST - 1) % 7  ->  Sun=0 .. Sat=6 under ANY DATEFIRST:
--     DATEFIRST 7: Sun dw=1 -> (1+6)%7=0 | Mon 2 -> 1 | ... | Fri 6 -> 5 | Sat 7 -> (7+6)%7=6
--     DATEFIRST 1: Mon dw=1 -> (1+0)%7=1 | ... | Sat 6 -> 6 | Sun 7 -> 7%7=0
--   Before this fix the SQL side compared the raw DATEPART, so Saturday (6) displayed as Friday
--   and the schedule-day guard disagreed with the day the scheduler actually fires.
-- Baseline: Item_PendingCostStatus_live_baseline.sql
CREATE OR ALTER PROCEDURE [dbo].[Item_PendingCostStatus]   -- EXEC dbo.Item_PendingCostStatus
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today       DATE = CAST(GETDATE() AS DATE);
    -- DECLARE @TodayDow    INT  = DATEPART(dw, @Today);   -- replaced 2026-08-29 DOW-FIX (plan-scheduler-dayofweek-fix-v1)
    DECLARE @TodayDow    INT  = (DATEPART(dw, @Today) + @@DATEFIRST - 1) % 7;   -- 0=Sun..6=Sat, matches stored DayOfWeek
    DECLARE @DayOfWeek   TINYINT;
    DECLARE @RunTime     TIME;
    DECLARE @IsEnabled   BIT;
    DECLARE @Pending1    INT;
    DECLARE @Pending2    INT;
    DECLARE @AppliedToday BIT = 0;
    DECLARE @NextApply   DATE;
    DECLARE @CanApply    BIT = 0;
    DECLARE @Reason      NVARCHAR(200) = NULL;

    SELECT @DayOfWeek = DayOfWeek, @RunTime = RunTime, @IsEnabled = IsEnabled
    FROM dbo.SchedulerConfig
    WHERE JobName = 'Update Item Prices';

    SELECT @Pending1 = SUM(CASE WHEN PendingBaseCost  IS NOT NULL THEN 1 ELSE 0 END),
           @Pending2 = SUM(CASE WHEN PendingBaseCost2 IS NOT NULL THEN 1 ELSE 0 END)
    FROM dbo.ItemUnit;

    IF EXISTS (SELECT 1 FROM dbo.ItemCostApply WHERE ScheduleDate = @Today AND UndoneAt IS NULL)
        SET @AppliedToday = 1;

    IF @DayOfWeek IS NOT NULL
        SET @NextApply = DATEADD(DAY, (@DayOfWeek - @TodayDow + 7) % 7, @Today);

    IF @DayOfWeek IS NULL
        SET @Reason = 'Schedule "Update Item Prices" is not configured.';
    ELSE IF @TodayDow <> @DayOfWeek
        SET @Reason = 'Prices can only be updated on the schedule day (' + DATENAME(WEEKDAY, @NextApply) + ' ' + CONVERT(NVARCHAR(10), @NextApply, 120) + ').';
    ELSE IF @AppliedToday = 1
        SET @Reason = 'Prices already updated this week.';
    ELSE IF ISNULL(@Pending1, 0) + ISNULL(@Pending2, 0) = 0
        SET @Reason = 'Nothing pending.';
    ELSE
        SET @CanApply = 1;

    SELECT
        ISNULL(@Pending1, 0)      AS PendingUnits1,
        ISNULL(@Pending2, 0)      AS PendingUnits2,
        @DayOfWeek                AS ScheduleDayOfWeek,
        CASE WHEN @DayOfWeek IS NULL THEN NULL ELSE DATENAME(WEEKDAY, @NextApply) END AS ScheduleDayName,
        @RunTime                  AS ScheduleTime,
        @IsEnabled                AS ScheduleEnabled,
        @NextApply                AS NextApplyDate,
        @AppliedToday             AS AppliedToday,
        la.ApplyId                AS LastApplyId,
        la.AppliedAt              AS LastAppliedAt,
        la.TriggeredBy            AS LastTriggeredBy,
        la.UnitCount1             AS LastUnitCount1,
        la.UnitCount2             AS LastUnitCount2,
        @CanApply                 AS CanApply,
        @Reason                   AS CannotApplyReason
    FROM (SELECT 1 AS x) one
    OUTER APPLY
    (
        SELECT TOP (1) ApplyId, AppliedAt, TriggeredBy, UnitCount1, UnitCount2
        FROM dbo.ItemCostApply
        WHERE UndoneAt IS NULL
        ORDER BY ApplyId DESC
    ) la;
END

GO
