-- 2026-08-28: plan-scheduler-email-hardening-v1 Slice 4 (D1=A, D3=yes)
-- Email Invoice job (Id=3) WEEKLY Mon 12:20 ET -> DAILY 12:20 ET.
-- NextRunTime reset so the scheduler recomputes under the new frequency.
-- Job stays disabled; Rajni enables it manually after slices 1-3 are deployed.
-- Rollback: SchedulerConfig_EmailInvoice_Daily_rollback.sql
UPDATE SchedulerConfig
SET Frequency = 'DAILY',
    DayOfWeek = NULL,
    NextRunTime = NULL,
    UpdatedAt = GETUTCDATE()
WHERE Id = 3 AND JobName = 'Email Invoice' AND Frequency = 'WEEKLY';
