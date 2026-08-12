-- ============================================================
-- Scheduler_ExpireSalesQuote  (2026-08-11)
--
-- New scheduler job: expire stale sales quotes daily.
-- Only Draft (0) and Sent (1) quotes are expired -> Expired (4).
-- Accepted / Rejected / Converted are never touched.
-- A quote expires the day AFTER its ExpiryDate (ExpiryDate < today),
-- so it remains valid through the whole expiry day.
-- Idempotent: re-running finds no matching rows and does nothing.
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Scheduler_ExpireSalesQuote] -- EXEC dbo.Scheduler_ExpireSalesQuote
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE SalesQuote
    SET StatusId = 4,               -- Expired
        UpdatedAt = GETUTCDATE()
    WHERE StatusId IN (0, 1)        -- Draft, Sent only
      AND ExpiryDate IS NOT NULL
      AND ExpiryDate < CAST(GETDATE() AS date);

END
GO

-- ============================================================
-- SchedulerConfig row (guarded: safe to re-run)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM SchedulerConfig WHERE SpName = 'Scheduler_ExpireSalesQuote')
BEGIN
    INSERT INTO SchedulerConfig
        (JobName, JobDescription, SpName, Frequency, RunTime, IsEnabled, CreatedAt)
    VALUES
        ('Expire Sales Quotes',
         'Daily job: set Draft/Sent sales quotes past their ExpiryDate to Expired.',
         'Scheduler_ExpireSalesQuote',
         'DAILY',
         '00:10',
         1,
         GETDATE());
END
GO
