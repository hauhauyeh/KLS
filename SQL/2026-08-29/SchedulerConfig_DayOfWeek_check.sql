SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-08-29 plan-scheduler-dayofweek-fix-v1 slice 2b
-- SchedulerConfig.DayOfWeek standard is Sun=0 .. Sat=6 (UI + ERPScheduler .NET DayOfWeek).
-- The original check was 1..7 (SQL DATEPART convention), which rejected Sunday (0) from the UI
-- and allowed 7, which the scheduler cannot represent. Align with CK_DeliverSchedule_DayOfWeek (0..6).
-- Existing rows (1, 6) are valid under both ranges - no data change. OriginalDayOfWeek has no check.
-- Rollback: SchedulerConfig_DayOfWeek_check_rollback.sql

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_SchedulerConfig_DayOfWeek' AND definition NOT LIKE '%>=(0)%')
    ALTER TABLE dbo.SchedulerConfig DROP CONSTRAINT CK_SchedulerConfig_DayOfWeek;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_SchedulerConfig_DayOfWeek')
    ALTER TABLE dbo.SchedulerConfig WITH CHECK
        ADD CONSTRAINT CK_SchedulerConfig_DayOfWeek CHECK ([DayOfWeek] IS NULL OR ([DayOfWeek] >= 0 AND [DayOfWeek] <= 6));
GO
