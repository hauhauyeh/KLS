/*
    Data_BackfillAutoSyncMarker_20260520_20260521_rollback.sql

    Reverses Data_BackfillAutoSyncMarker_20260520_20260521.sql by setting
    Notes back to NULL on the same target rows.

    Uses the same heuristic to scope the rows, then sets Notes back to NULL
    only where Notes = 'Auto Sync' (so it never wipes a manually-set Notes
    value entered between the backfill and the rollback).
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @tz NVARCHAR(100);
SELECT @tz = Timezone FROM Company;

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

BEGIN TRAN;

UPDATE t
SET t.Notes = NULL
FROM Timesheet t
INNER JOIN @TargetIds tt ON tt.TimesheetId = t.TimesheetId
WHERE t.Notes = 'Auto Sync';

PRINT '--- Timesheet headers reverted: ---';
SELECT @@ROWCOUNT AS HeadersReverted;

UPDATE td
SET td.Notes = NULL
FROM TimesheetDetail td
INNER JOIN @TargetIds tt ON tt.TimesheetId = td.TimesheetId
WHERE td.JobCode = 'D'
  AND td.Notes = 'Auto Sync';

PRINT '--- TimesheetDetail rows reverted: ---';
SELECT @@ROWCOUNT AS DetailsReverted;

COMMIT;

-- Verification.
SELECT t.TimesheetId, p.PayeeName,
       CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @tz AS DATE) AS Day,
       td.Route, t.Notes AS HeaderNotes, td.Notes AS DetailNotes
FROM @TargetIds tt
INNER JOIN Timesheet t ON t.TimesheetId = tt.TimesheetId
INNER JOIN Payee p ON p.PayeeId = t.PayeeId
INNER JOIN TimesheetDetail td ON td.TimesheetId = t.TimesheetId
ORDER BY t.InTime, p.PayeeName;
