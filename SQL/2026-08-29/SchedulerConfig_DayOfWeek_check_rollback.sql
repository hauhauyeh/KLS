SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Rollback for SchedulerConfig_DayOfWeek_check.sql (2026-08-29): restore the original 1..7 check.
-- NOTE: fails if any row holds DayOfWeek = 0 (a Sunday schedule); set those rows first.

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_SchedulerConfig_DayOfWeek')
    ALTER TABLE dbo.SchedulerConfig DROP CONSTRAINT CK_SchedulerConfig_DayOfWeek;
GO

ALTER TABLE dbo.SchedulerConfig WITH CHECK
    ADD CONSTRAINT CK_SchedulerConfig_DayOfWeek CHECK ([DayOfWeek] >= 1 AND [DayOfWeek] <= 7);
GO
