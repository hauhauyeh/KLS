-- Rollback for SchedulerConfig_EmailInvoice_Daily.sql (2026-08-28)
UPDATE SchedulerConfig
SET Frequency = 'WEEKLY',
    DayOfWeek = 1,
    NextRunTime = NULL,
    UpdatedAt = GETUTCDATE()
WHERE Id = 3 AND JobName = 'Email Invoice' AND Frequency = 'DAILY';
