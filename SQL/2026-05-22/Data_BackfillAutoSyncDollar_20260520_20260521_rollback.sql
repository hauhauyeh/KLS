/*
    Data_BackfillAutoSyncDollar_20260520_20260521_rollback.sql
    2026-05-22

    Reverses Data_BackfillAutoSyncDollar_20260520_20260521.sql.
    Restores td.Notes to NULL on any row whose Notes was set by the forward
    script (matches the 'Auto Sync $...' pattern on a 5/20 or 5/21 D row).

    Safe to run if forward was never deployed -- the WHERE clause will match
    zero rows.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @tz NVARCHAR(100); SELECT @tz = Timezone FROM Company;

UPDATE td
SET td.Notes = NULL
FROM TimesheetDetail td
INNER JOIN Timesheet t ON t.TimesheetId = td.TimesheetId
WHERE td.JobCode = 'D'
  AND td.Notes LIKE 'Auto Sync $%'
  AND CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @tz AS DATE) IN ('2026-05-20', '2026-05-21');

PRINT '--- Rows reverted: ---';
SELECT @@ROWCOUNT AS RowsReverted;
