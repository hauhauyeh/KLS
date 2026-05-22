/*
    Data_BackfillAutoSyncMarker_20260520_20260521.sql
    2026-05-21

    Backfills Notes='Auto Sync' on Timesheet headers + TimesheetDetail rows
    that were inserted by the prior Scheduler_ImportDriverTimesheet runs
    on 2026-05-20 and 2026-05-21, before the marker logic was deployed.

    Heuristic match (same shape the old scheduler produced):
      - Timesheet.InTime exactly 09:00:00 in company local time
      - The Timesheet has at least one TimesheetDetail with JobCode='D'
      - That detail's Route matches a SalesRoute row for the same driver
        and date (sr.DriverId, sr.ShipDate, sr.ShipRoute)

    Idempotent — only touches rows whose Notes IS NULL. Safe to re-run.

    Rollback: Data_BackfillAutoSyncMarker_20260520_20260521_rollback.sql
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @tz NVARCHAR(100);
SELECT @tz = Timezone FROM Company;

-- Identify the Timesheet IDs that match the scheduler signature for the
-- two target days.
DECLARE @TargetIds TABLE (TimesheetId INT PRIMARY KEY);

INSERT INTO @TargetIds (TimesheetId)
SELECT DISTINCT t.TimesheetId
FROM Timesheet t
INNER JOIN TimesheetDetail td ON td.TimesheetId = t.TimesheetId
WHERE CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @tz AS DATE) IN ('2026-05-20', '2026-05-21')
  AND DATEPART(HOUR,   t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @tz) = 9
  AND DATEPART(MINUTE, t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @tz) = 0
  AND td.JobCode = 'D'
  AND td.Route IS NOT NULL
  AND EXISTS (
      SELECT 1 FROM SalesRoute sr
      WHERE sr.DriverId  = t.PayeeId
        AND sr.ShipDate  = CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @tz AS DATE)
        AND sr.ShipRoute = td.Route
  );

-- Preview before applying.
PRINT '--- Target Timesheet count: ---';
SELECT COUNT(*) AS TargetTimesheetCount FROM @TargetIds;

PRINT '--- Target rows preview: ---';
SELECT t.TimesheetId, p.PayeeName,
       CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @tz AS DATE) AS Day,
       td.Route, t.Notes AS HeaderNotes, td.Notes AS DetailNotes
FROM @TargetIds tt
INNER JOIN Timesheet t ON t.TimesheetId = tt.TimesheetId
INNER JOIN Payee p ON p.PayeeId = t.PayeeId
INNER JOIN TimesheetDetail td ON td.TimesheetId = t.TimesheetId
ORDER BY t.InTime, p.PayeeName;

-- Apply: only set Notes where currently NULL (idempotent + non-destructive
-- if a row has been manually re-noted in the meantime).
BEGIN TRAN;

UPDATE t
SET t.Notes = 'Auto Sync'
FROM Timesheet t
INNER JOIN @TargetIds tt ON tt.TimesheetId = t.TimesheetId
WHERE t.Notes IS NULL;

PRINT '--- Timesheet headers updated: ---';
SELECT @@ROWCOUNT AS HeadersUpdated;

UPDATE td
SET td.Notes = 'Auto Sync'
FROM TimesheetDetail td
INNER JOIN @TargetIds tt ON tt.TimesheetId = td.TimesheetId
WHERE td.JobCode = 'D'
  AND td.Notes IS NULL;

PRINT '--- TimesheetDetail rows updated: ---';
SELECT @@ROWCOUNT AS DetailsUpdated;

COMMIT;

-- Verification.
PRINT '--- After-state for target rows: ---';
SELECT t.TimesheetId, p.PayeeName,
       CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @tz AS DATE) AS Day,
       td.Route, t.Notes AS HeaderNotes, td.Notes AS DetailNotes
FROM @TargetIds tt
INNER JOIN Timesheet t ON t.TimesheetId = tt.TimesheetId
INNER JOIN Payee p ON p.PayeeId = t.PayeeId
INNER JOIN TimesheetDetail td ON td.TimesheetId = t.TimesheetId
ORDER BY t.InTime, p.PayeeName;
