SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[_Backfill_TimesheetNotes];
GO

CREATE PROCEDURE [dbo].[_Backfill_TimesheetNotes]    -- EXEC _Backfill_TimesheetNotes @TargetDate='2026-05-27'                  -- preview (default DryRun=1)
-- EXEC _Backfill_TimesheetNotes @TargetDate='2026-05-27', @DryRun=0       -- apply (commits)
    @TargetDate DATE,                 -- required; pick the ShipDate window to scan
    @DryRun     BIT  = 1              -- default 1 = preview only (no writes). Set 0 to actually update.
AS
BEGIN
    SET NOCOUNT ON;

    /*
      One-off / on-demand backfill tool for TimesheetDetail rows whose Notes
      field is missing or blank. Targets rows manually entered through the
      Timesheet UI before the scheduler ran (or while the scheduler dedup
      skipped them) -- they ended up with NULL / whitespace Notes, but the
      payroll report expects the canonical system-tagged format.

      WHAT IT TOUCHES (filter):
        - TimesheetDetail rows whose parent Timesheet's local-date InTime
          equals @TargetDate
        - JobCode IN ('L', 'D')
        - Route IS NOT NULL
        - Notes is NULL or whitespace-only (NULLIF(LTRIM(RTRIM(...)), ''))

      WHAT IT WRITES:
        Driver: 'Auto Sync $X,XXX.XX'      (matches Scheduler_ImportDriverTimesheet)
        Loader: 'System Loader ($X,XXX.XX)'

      WORKFLOW:
        1. EXEC _Backfill_TimesheetNotes @TargetDate='2026-05-22'
           -> Preview (DryRun=1 default). Returns the rows that WOULD be
              updated along with OldNotes / NewNotes columns. No writes.
        2. Review the preview. If happy:
           EXEC _Backfill_TimesheetNotes @TargetDate='2026-05-22', @DryRun=0
           -> Apply. Returns the rows that WERE updated. Auto-commits.

      IDEMPOTENT: re-running with @DryRun=0 only touches NULL/blank Notes,
      so already-fixed rows are skipped on subsequent runs. Safe to invoke
      again if the preview was empty or you want to confirm "nothing left
      to fix" for a given date.

      Naming: leading underscore '_' signals operator-tool / one-off rather
      than a normal app SP. Sorts to the top of the procedure list.

      Read-only-mode requirement: @TargetDate is required (no default to
      today) so an accidental "EXEC _Backfill_TimesheetNotes" never silently
      rewrites today's notes.
    */

    DECLARE @CompanyTimezone NVARCHAR(100);
    SELECT @CompanyTimezone = Timezone FROM dbo.Company;

    -- Shared route-totals CTE pre-computed once; both preview and apply
    -- paths use the same Sales SUM, so the dollar amount in NewNotes stays
    -- consistent across the two calls (no risk of preview vs apply showing
    -- different numbers due to mid-day Sales changes).
    -- Materializing into a table variable avoids two CTE expansions and
    -- keeps the IF/ELSE branches readable.
    DECLARE @RouteTotals TABLE (
        ShipDate   DATE          NOT NULL,
        ShipRoute  NVARCHAR(10)  NOT NULL,
        RouteTotal DECIMAL(18,2) NOT NULL,
        PRIMARY KEY (ShipDate, ShipRoute)
    );

    -- 2026-05-27: filter NULL ShipRoute. Sales rows without a route can't
    -- match any TimesheetDetail.Route (we already require td.Route IS NOT NULL
    -- below), and the @RouteTotals PK forbids NULL ShipRoute anyway. Hit on
    -- prod data for 5/26 where some Sales rows had NULL ShipRoute.
    INSERT INTO @RouteTotals (ShipDate, ShipRoute, RouteTotal)
    SELECT ShipDate, ShipRoute, ISNULL(SUM(SalesTotal), 0)
    FROM dbo.Sales
    WHERE ShipDate = @TargetDate
      AND ShipRoute IS NOT NULL
    GROUP BY ShipDate, ShipRoute;

    IF @DryRun = 1
    BEGIN
        -- PREVIEW: just the SELECT, no writes. Shows what apply would do.
        SELECT
            td.TimesheetDetailId,
            t.PayeeId,
            pe.PayeeName,
            td.JobCode,
            td.Route,
            rt.RouteTotal,
            td.Notes AS OldNotes,
            CASE td.JobCode
                WHEN 'L' THEN 'System Loader (' + FORMAT(ISNULL(rt.RouteTotal, 0), 'C', 'en-US') + ')'
                WHEN 'D' THEN 'Auto Sync ' + FORMAT(ISNULL(rt.RouteTotal, 0), 'C', 'en-US')
            END AS NewNotes
        FROM dbo.TimesheetDetail td
        INNER JOIN dbo.Timesheet  t  ON t.TimesheetId = td.TimesheetId
        INNER JOIN dbo.Payee      pe ON pe.PayeeId    = t.PayeeId
        LEFT  JOIN @RouteTotals   rt ON rt.ShipDate   = @TargetDate
                                    AND rt.ShipRoute  = td.Route
        WHERE CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @CompanyTimezone AS DATE) = @TargetDate
          AND td.JobCode IN ('L','D')
          AND td.Route IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(td.Notes)), '') IS NULL
        ORDER BY pe.PayeeName, td.JobCode, td.Route;

        RETURN;
    END

    -- APPLY: write the canonical Notes string. Idempotent via the NULL/blank
    -- filter; rows already filled by a prior run are skipped automatically.
    DECLARE @Updated TABLE (
        TimesheetDetailId INT           NOT NULL,
        OldNotes          NVARCHAR(255) NULL,
        NewNotes          NVARCHAR(255) NULL
    );

    UPDATE td
    SET td.Notes = CASE td.JobCode
        WHEN 'L' THEN 'System Loader (' + FORMAT(ISNULL(rt.RouteTotal, 0), 'C', 'en-US') + ')'
        WHEN 'D' THEN 'Auto Sync ' + FORMAT(ISNULL(rt.RouteTotal, 0), 'C', 'en-US')
    END
    OUTPUT inserted.TimesheetDetailId,
           deleted.Notes  AS OldNotes,
           inserted.Notes AS NewNotes
    INTO   @Updated
    FROM dbo.TimesheetDetail td
    INNER JOIN dbo.Timesheet  t  ON t.TimesheetId = td.TimesheetId
    LEFT  JOIN @RouteTotals   rt ON rt.ShipDate   = @TargetDate
                                AND rt.ShipRoute  = td.Route
    WHERE CAST(t.InTime AT TIME ZONE 'UTC' AT TIME ZONE @CompanyTimezone AS DATE) = @TargetDate
      AND td.JobCode IN ('L','D')
      AND td.Route IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(td.Notes)), '') IS NULL;

    -- Result set: exactly the rows that were updated, with before/after.
    SELECT
        u.TimesheetDetailId,
        t.PayeeId,
        pe.PayeeName,
        td.JobCode,
        td.Route,
        u.OldNotes,
        u.NewNotes,
        td.Notes AS CurrentNotes
    FROM @Updated u
    INNER JOIN dbo.TimesheetDetail td ON td.TimesheetDetailId = u.TimesheetDetailId
    INNER JOIN dbo.Timesheet       t  ON t.TimesheetId        = td.TimesheetId
    INNER JOIN dbo.Payee           pe ON pe.PayeeId           = t.PayeeId
    ORDER BY pe.PayeeName, td.JobCode, td.Route;
END
GO
