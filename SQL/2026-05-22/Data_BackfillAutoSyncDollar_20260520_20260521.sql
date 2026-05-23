/*
    Data_BackfillAutoSyncDollar_20260520_20260521.sql
    2026-05-22

    Backfill TimesheetDetail.Notes = 'Auto Sync $X,XXX.XX' for 5/20 and 5/21,
    matching the new Scheduler_ImportDriverTimesheet output format.

    Earlier 5/21 backfill (Data_BackfillAutoSyncMarker_20260520_20260521.sql)
    only set plain 'Auto Sync' on the detail rows. This script supersedes that
    by writing the dollar amount from the route's Sales total.

    Coverage on prod (verified 2026-05-22 read-only audit):
        5/20: 8 driver detail rows (all 8 SalesRoute driver assignments)
        5/21: 9 driver detail rows (all 9 SalesRoute driver assignments)
        All currently NULL Notes -> 17 rows updated by this script.

    Safety:
        - Only touches rows with td.JobCode = 'D' (no Loader/Warehouse).
        - Only touches rows with td.Notes IS NULL (preserves manual edits).
        - Only touches rows where (Date, Route, DriverId) matches a real
          SalesRoute assignment (no orphan driver-rows updated).
        - Excludes route codes 'P' and 'CM' (consistent with the new SP).
        - Idempotent: re-running is a no-op once Notes is populated.

    Rollback: Data_BackfillAutoSyncDollar_20260520_20260521_rollback.sql
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @tz NVARCHAR(100); SELECT @tz = Timezone FROM Company;

-- Compute each (date, route) dollar total from Sales -- same formula as the
-- new Scheduler_ImportDriverTimesheet uses (Report_JobSummary RouteTotal).
;WITH RouteTotals AS (
    SELECT s.ShipDate,
           s.ShipRoute,
           ISNULL(SUM(s.SalesTotal), 0) AS RouteTotal
    FROM Sales s
    WHERE s.ShipDate IN ('2026-05-20', '2026-05-21')
    GROUP BY s.ShipDate, s.ShipRoute
)
UPDATE td
SET td.Notes = 'Auto Sync ' + FORMAT(rt.RouteTotal, 'C', 'en-US')
FROM TimesheetDetail td
INNER JOIN Timesheet t ON t.TimesheetId = td.TimesheetId
INNER JOIN RouteTotals rt
    ON rt.ShipRoute = td.Route
    AND rt.ShipDate = CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @tz AS DATE)
WHERE td.JobCode = 'D'
  AND td.Route NOT IN ('P', 'CM')
  AND td.Notes IS NULL
  AND CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @tz AS DATE) IN ('2026-05-20', '2026-05-21')
  AND EXISTS (
      SELECT 1 FROM SalesRoute sr
      WHERE sr.ShipDate = rt.ShipDate
        AND sr.ShipRoute = td.Route
        AND sr.DriverId = t.PayeeId
  );

PRINT '--- Rows updated this run: ---';
SELECT @@ROWCOUNT AS RowsUpdated;

-- Post-state preview (read-only).
PRINT '--- After-state for 5/20 and 5/21 driver detail rows: ---';
SELECT
    CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @tz AS DATE) AS Day,
    p.PayeeName AS Driver,
    td.Route,
    td.Notes
FROM TimesheetDetail td
INNER JOIN Timesheet t ON t.TimesheetId = td.TimesheetId
INNER JOIN Payee p ON p.PayeeId = t.PayeeId
WHERE td.JobCode = 'D'
  AND CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @tz AS DATE) IN ('2026-05-20', '2026-05-21')
ORDER BY Day, td.Route;
