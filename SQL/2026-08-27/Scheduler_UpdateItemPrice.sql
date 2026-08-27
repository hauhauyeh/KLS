-- ============================================================
-- Scheduler_UpdateItemPrice  (2026-08-27, NEW)
--
-- Scheduler job 'Update Item Prices' (SchedulerConfig row already exists:
-- WEEKLY, DayOfWeek = 2 = Monday, 06:00; SpName = this proc). The runner
-- EXECs SpName with no parameters and logs to SchedulerLog.
--
-- Thin wrapper over Item_ApplyPendingCost. Two outcomes are NOT errors
-- for a scheduled run and return quietly so the log shows Success:
--   51062  prices already updated today (someone pressed Apply Now first)
--   51063  nothing pending
-- Anything else re-throws so the log shows Failed with the real message.
--
-- The schedule-day guard cannot normally fire here (the runner only calls
-- on DayOfWeek) but stays inside Item_ApplyPendingCost as defence.
-- No SchedulerConfig insert in this file: the row exists; enabling it is
-- the separate ops script SchedulerConfig_ItemPrice_ops.sql.
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Scheduler_UpdateItemPrice]   -- EXEC dbo.Scheduler_UpdateItemPrice
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ApplyId   INT;
    DECLARE @UnitCount INT;

    BEGIN TRY
        EXEC dbo.Item_ApplyPendingCost
            @TriggeredBy = 'SCHEDULER',
            @EmpId       = NULL,
            @ApplyId     = @ApplyId OUTPUT,
            @UnitCount   = @UnitCount OUTPUT;

        SELECT @ApplyId AS ApplyId, @UnitCount AS UnitCount, 'Applied' AS Outcome;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (51062, 51063)
        BEGIN
            SELECT NULL AS ApplyId, 0 AS UnitCount, 'Skipped: ' + ERROR_MESSAGE() AS Outcome;
            RETURN;
        END

        ;THROW;
    END CATCH
END
GO
