/*
    AddSalesRouteLoaderId.sql
    2026-05-25

    Phase 1 of the Loader auto-sync upgrade:
      - Add SalesRoute.LoaderId INT NULL (mirrors DriverId added 2026-05-04).
      - Backfill LoaderId for existing rows by name-matching Loader text
        against Payee.PayeeName, defensive against duplicate PayeeNames.

    SalesRoute.Loader text column stays — denormalized PayeeName cache,
    same pattern as Driver/DriverId. Reports and invoice PDFs continue
    reading the text column unchanged.

    Audit confirmed on 2026-05-25:
      - Payee.PayeeName has zero duplicates in the table.
      - All 8 distinct historical Loader values resolve to exactly 1 PayeeId.
      - Defensive HAVING COUNT(DISTINCT PayeeId) = 1 still applied so the
        script stays safe if a duplicate PayeeName ever appears later.

    Rollback: AddSalesRouteLoaderId_rollback.sql
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Step 1: Add the column (no-op if already exists, allows re-run).
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.SalesRoute') AND name = 'LoaderId'
)
BEGIN
    ALTER TABLE dbo.SalesRoute ADD LoaderId INT NULL;
END;
GO

-- Step 2: Pre-backfill ambiguity report. Expect zero rows. If non-empty,
-- review and manually decide which PayeeId is correct for each Loader name
-- BEFORE the backfill UPDATE runs (the UPDATE will silently skip ambiguous
-- names).
-- Note: aggregate over distinct (Loader, PayeeId) pairs first, NOT the raw
-- JOIN, to avoid STRING_AGG overflow when a Loader name appears on thousands
-- of SalesRoute rows.
PRINT '--- Ambiguity report (expect zero rows): Loader names matching > 1 Payee ---';
;WITH LoaderPayeePairs AS (
    SELECT DISTINCT sr.Loader, p.PayeeId
    FROM dbo.SalesRoute sr
    LEFT JOIN dbo.Payee p ON p.PayeeName = sr.Loader
    WHERE sr.Loader IS NOT NULL AND LTRIM(RTRIM(sr.Loader)) <> ''
),
LoaderRouteCounts AS (
    SELECT sr.Loader, COUNT(*) AS AffectedRouteRows
    FROM dbo.SalesRoute sr
    WHERE sr.Loader IS NOT NULL AND LTRIM(RTRIM(sr.Loader)) <> ''
    GROUP BY sr.Loader
)
SELECT lpp.Loader,
       COUNT(*) AS DistinctPayeeMatches,
       STRING_AGG(CAST(lpp.PayeeId AS VARCHAR), ',') AS PayeeIds,
       lrc.AffectedRouteRows
FROM LoaderPayeePairs lpp
INNER JOIN LoaderRouteCounts lrc ON lrc.Loader = lpp.Loader
GROUP BY lpp.Loader, lrc.AffectedRouteRows
HAVING COUNT(*) <> 1
ORDER BY lpp.Loader;

-- Step 3: Backfill LoaderId from Loader text, only for unique matches.
-- Mirrors SalesRouteService.cs:132-134 defensive pattern.
;WITH UniqueLoader AS (
    SELECT sr.Loader, MIN(p.PayeeId) AS PayeeId
    FROM dbo.SalesRoute sr
    INNER JOIN dbo.Payee p ON p.PayeeName = sr.Loader
    WHERE sr.Loader IS NOT NULL AND LTRIM(RTRIM(sr.Loader)) <> ''
    GROUP BY sr.Loader
    HAVING COUNT(DISTINCT p.PayeeId) = 1
)
UPDATE sr
SET sr.LoaderId = ul.PayeeId
FROM dbo.SalesRoute sr
INNER JOIN UniqueLoader ul ON ul.Loader = sr.Loader
WHERE sr.LoaderId IS NULL;

PRINT '--- Rows updated by backfill: ---';
SELECT @@ROWCOUNT AS RowsUpdated;

-- Step 4: Verify zero unresolved rows. If non-empty, that means either
-- (a) ambiguity report above had rows (admin decision needed), or
-- (b) Loader text references a name no longer in Payee (employee deleted).
PRINT '--- Post-backfill unresolved (expect zero rows): ---';
SELECT sr.Loader, COUNT(*) AS UnresolvedRows
FROM dbo.SalesRoute sr
WHERE sr.LoaderId IS NULL
  AND sr.Loader IS NOT NULL
  AND LTRIM(RTRIM(sr.Loader)) <> ''
GROUP BY sr.Loader
ORDER BY sr.Loader;

PRINT '--- Final state: LoaderId population ---';
SELECT
    COUNT(*) AS TotalRows,
    SUM(CASE WHEN LoaderId IS NOT NULL THEN 1 ELSE 0 END) AS WithLoaderId,
    SUM(CASE WHEN Loader IS NOT NULL THEN 1 ELSE 0 END) AS WithLoaderText
FROM dbo.SalesRoute;
