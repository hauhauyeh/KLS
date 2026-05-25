/*
    AddSalesRouteCheckerIdOfficerId.sql
    2026-05-25

    Finish the FK upgrade started by the 2026-05-04 DriverId addition and
    the 2026-05-25 LoaderId addition. Adds CheckerId and OfficerId so all
    four crew-role text fields on SalesRoute now have a matching FK
    counterpart, same source-of-truth pattern: FK is canonical, text
    column is a denormalized PayeeName cache.

    Scope: schema + UI FK plumbing only. No auto-sync into Timesheet for
    Checker or Officer in this round -- EmpJob does not have JobCode='Check'
    or 'Officer' entries (only D=Deliver and L=Load are wired through
    Scheduler_ImportDriverTimesheet). Adding those is a separate business
    decision (does payroll want Checkers/Officers in timesheet detail rows?).

    Audit confirmed on 2026-05-25:
      - Checker: 8 distinct historical values, each resolves to exactly
        1 PayeeId. No ambiguity.
      - Officer: 10 distinct historical values, each resolves to exactly
        1 PayeeId. No ambiguity.
      - Backfill uses the same defensive CTE + HAVING COUNT(DISTINCT) = 1
        pattern as Loader so a future duplicate PayeeName never produces
        a nondeterministic assignment.

    Rollback: AddSalesRouteCheckerIdOfficerId_rollback.sql
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Step 1: Add the columns (idempotent).
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.SalesRoute') AND name = 'CheckerId'
)
BEGIN
    ALTER TABLE dbo.SalesRoute ADD CheckerId INT NULL;
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.SalesRoute') AND name = 'OfficerId'
)
BEGIN
    ALTER TABLE dbo.SalesRoute ADD OfficerId INT NULL;
END;
GO

-- Step 2: Pre-backfill ambiguity reports. Expect zero rows for both.
PRINT '--- Checker ambiguity report (expect zero rows): ---';
;WITH P AS (
    SELECT DISTINCT sr.Checker, p.PayeeId
    FROM dbo.SalesRoute sr LEFT JOIN dbo.Payee p ON p.PayeeName = sr.Checker
    WHERE sr.Checker IS NOT NULL AND LTRIM(RTRIM(sr.Checker)) <> ''
),
R AS (
    SELECT Checker, COUNT(*) AS AffectedRouteRows
    FROM dbo.SalesRoute
    WHERE Checker IS NOT NULL AND LTRIM(RTRIM(Checker)) <> ''
    GROUP BY Checker
)
SELECT P.Checker, COUNT(*) AS DistinctPayeeMatches,
       STRING_AGG(CAST(P.PayeeId AS VARCHAR), ',') AS PayeeIds,
       R.AffectedRouteRows
FROM P INNER JOIN R ON R.Checker = P.Checker
GROUP BY P.Checker, R.AffectedRouteRows
HAVING COUNT(*) <> 1
ORDER BY P.Checker;

PRINT '--- Officer ambiguity report (expect zero rows): ---';
;WITH P AS (
    SELECT DISTINCT sr.Officer, p.PayeeId
    FROM dbo.SalesRoute sr LEFT JOIN dbo.Payee p ON p.PayeeName = sr.Officer
    WHERE sr.Officer IS NOT NULL AND LTRIM(RTRIM(sr.Officer)) <> ''
),
R AS (
    SELECT Officer, COUNT(*) AS AffectedRouteRows
    FROM dbo.SalesRoute
    WHERE Officer IS NOT NULL AND LTRIM(RTRIM(Officer)) <> ''
    GROUP BY Officer
)
SELECT P.Officer, COUNT(*) AS DistinctPayeeMatches,
       STRING_AGG(CAST(P.PayeeId AS VARCHAR), ',') AS PayeeIds,
       R.AffectedRouteRows
FROM P INNER JOIN R ON R.Officer = P.Officer
GROUP BY P.Officer, R.AffectedRouteRows
HAVING COUNT(*) <> 1
ORDER BY P.Officer;

-- Step 3: Backfill CheckerId (only unique matches).
;WITH UniqueChecker AS (
    SELECT sr.Checker, MIN(p.PayeeId) AS PayeeId
    FROM dbo.SalesRoute sr
    INNER JOIN dbo.Payee p ON p.PayeeName = sr.Checker
    WHERE sr.Checker IS NOT NULL AND LTRIM(RTRIM(sr.Checker)) <> ''
    GROUP BY sr.Checker
    HAVING COUNT(DISTINCT p.PayeeId) = 1
)
UPDATE sr
SET sr.CheckerId = uc.PayeeId
FROM dbo.SalesRoute sr
INNER JOIN UniqueChecker uc ON uc.Checker = sr.Checker
WHERE sr.CheckerId IS NULL;

PRINT '--- CheckerId rows updated by backfill: ---';
SELECT @@ROWCOUNT AS RowsUpdated;

-- Step 4: Backfill OfficerId (only unique matches).
;WITH UniqueOfficer AS (
    SELECT sr.Officer, MIN(p.PayeeId) AS PayeeId
    FROM dbo.SalesRoute sr
    INNER JOIN dbo.Payee p ON p.PayeeName = sr.Officer
    WHERE sr.Officer IS NOT NULL AND LTRIM(RTRIM(sr.Officer)) <> ''
    GROUP BY sr.Officer
    HAVING COUNT(DISTINCT p.PayeeId) = 1
)
UPDATE sr
SET sr.OfficerId = uo.PayeeId
FROM dbo.SalesRoute sr
INNER JOIN UniqueOfficer uo ON uo.Officer = sr.Officer
WHERE sr.OfficerId IS NULL;

PRINT '--- OfficerId rows updated by backfill: ---';
SELECT @@ROWCOUNT AS RowsUpdated;

-- Step 5: Final state.
PRINT '--- Final SalesRoute FK population ---';
SELECT
    COUNT(*) AS TotalRows,
    SUM(CASE WHEN DriverId IS NOT NULL THEN 1 ELSE 0 END) AS WithDriverId,
    SUM(CASE WHEN LoaderId IS NOT NULL THEN 1 ELSE 0 END) AS WithLoaderId,
    SUM(CASE WHEN CheckerId IS NOT NULL THEN 1 ELSE 0 END) AS WithCheckerId,
    SUM(CASE WHEN OfficerId IS NOT NULL THEN 1 ELSE 0 END) AS WithOfficerId
FROM dbo.SalesRoute;
