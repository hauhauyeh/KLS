-- =============================================================================
-- BombUnit_CrossedRows_Fix.sql  (Phase 2 data remediation) -- PROD-READY
-- Re-point the WRONG ItemUnitId on SalesDetail rows crossed by the bomb-sales
-- UpdateUnit bug (fixed in code Phase 1: TempBombSalesService.UpdateUnit).
--
-- >>> RUN ORDER: deploy the Phase 1 CODE FIX to prod FIRST, then run this. <<<
--     (Otherwise new crossings keep forming after the data is cleaned.)
--
-- WHAT a crossed row is: Unit/FactorToBase snapshot describes a real non-base unit
--   (e.g. 'lb'/30) but ItemUnitId points at a DIFFERENT unit (base 'cs'/1). The
--   snapshot is authoritative and matches posted qty/value; only ItemUnitId is wrong.
--   Fix = re-point ItemUnitId to the sibling unit that matches the snapshot EXACTLY
--   (same Unit name AND FactorToBase). NOTHING ELSE CHANGES: no Unit, FactorToBase,
--   qty, price, ExtTotal, or journal. (Base*Qty derive from FactorToBase, untouched.)
--
-- SCOPE: recent bomb crossings with an EXACT (name+factor) target (active preferred,
--   else the correct INACTIVE/deactivated unit). Re-detects LIVE, so it also fixes any
--   NEW crossed rows created before you run it. Also clears in-flight TempBombSales
--   crossed draft rows so they can't re-inject.
--   INTENTIONALLY SKIPPED (do NOT auto-fix): factor-only "name-drift" rows = 2024 legacy
--   'cluster B' (GBV/RNBP1/BENTSSSA) and any ambiguous/no-match rows. They are a separate
--   issue and are listed as SKIPPED in the preview for manual handling.
--   Also NOT this script's problem: stale-FactorToBase rows (SalesRouteDetail/PurchaseDetail).
--
-- ROLLBACK: dbo._Fix_BombUnitCrossed_Backup holds (SalesDetailId, Old, New).
--   See BombUnit_CrossedRows_Fix_rollback.sql.
--
-- HOW TO RUN (two passes):
--   1) Leave @Apply = 0 below, run the whole script -> PREVIEW only, no changes.
--      Review the mapping (esp. any 'INACTIVE' or 'SKIPPED' rows).
--   2) Set @Apply = 1, run the whole script again -> backs up + re-points + clears
--      temp + verifies, all in one transaction (auto-rollback on any error).
-- =============================================================================
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- ============================ SAFETY GATE ====================================
DECLARE @Apply BIT = 0;   -- 0 = PREVIEW ONLY.  Set to 1 to actually apply.
-- =============================================================================

-- Build the mapping: crossed SalesDetail -> unique EXACT-match target unit.
IF OBJECT_ID('tempdb..#Fix') IS NOT NULL DROP TABLE #Fix;

;WITH crossed AS (
    SELECT sd.SalesDetailId, sd.ItemId, sd.Unit AS snapUnit, sd.FactorToBase AS snapF,
           sd.ItemUnitId AS cur_id, iu.Unit AS cur_unit
    FROM SalesDetail sd
    JOIN ItemUnit iu ON iu.ItemUnitId = sd.ItemUnitId
    WHERE sd.ItemId IS NOT NULL
      AND sd.FactorToBase IS NOT NULL
      AND sd.FactorToBase <> iu.FactorToBase        -- factor mismatch
      AND sd.Unit <> iu.Unit                        -- pointed unit is a DIFFERENT unit (wrong-id, not stale-factor)
      AND EXISTS (SELECT 1 FROM ItemUnit s WHERE s.ItemId = sd.ItemId AND s.FactorToBase = sd.FactorToBase)
),
mapped AS (
    SELECT c.*,
        -- EXACT (name + factor). Active preferred; fall back to an INACTIVE exact match
        -- (the correct historical unit may have been deactivated after the sale).
        -- NO factor-only fallback: that is the 2024 legacy name-drift 'cluster B' -> leave it.
        a_exact_id  = (SELECT MIN(t.ItemUnitId) FROM ItemUnit t WHERE t.ItemId=c.ItemId AND t.Unit=c.snapUnit AND t.FactorToBase=c.snapF AND t.Inactive=0),
        a_exact_cnt = (SELECT COUNT(*)          FROM ItemUnit t WHERE t.ItemId=c.ItemId AND t.Unit=c.snapUnit AND t.FactorToBase=c.snapF AND t.Inactive=0),
        x_exact_id  = (SELECT MIN(t.ItemUnitId) FROM ItemUnit t WHERE t.ItemId=c.ItemId AND t.Unit=c.snapUnit AND t.FactorToBase=c.snapF),
        x_exact_cnt = (SELECT COUNT(*)          FROM ItemUnit t WHERE t.ItemId=c.ItemId AND t.Unit=c.snapUnit AND t.FactorToBase=c.snapF)
    FROM crossed c
)
SELECT
    m.SalesDetailId, m.ItemId, m.snapUnit, m.snapF, m.cur_id, m.cur_unit,
    target_id = CASE WHEN m.a_exact_cnt = 1 THEN m.a_exact_id
                     WHEN m.x_exact_cnt = 1 THEN m.x_exact_id
                     ELSE NULL END,
    match_kind = CASE WHEN m.a_exact_cnt = 1 THEN 'active exact (name+factor)'
                      WHEN m.x_exact_cnt = 1 THEN 'INACTIVE exact (deactivated unit)'
                      ELSE 'SKIPPED (no exact match: legacy name-drift or ambiguous - manual)' END
INTO #Fix
FROM mapped m;

-- --------------------------- PREVIEW (always) --------------------------------
SELECT
    f.SalesDetailId, i.ItemCode,
    snap_unit = f.snapUnit, snap_factor = f.snapF,
    now_points_to   = CAST(f.cur_id AS VARCHAR(12)) + ' (' + f.cur_unit + ')',
    will_repoint_to = CASE WHEN f.target_id IS NULL THEN NULL
                           ELSE CAST(f.target_id AS VARCHAR(12)) + ' (' + tu.Unit + ' /' + CAST(tu.FactorToBase AS VARCHAR(20)) + ')' END,
    f.match_kind
FROM #Fix f
JOIN Item i ON i.ItemId = f.ItemId
LEFT JOIN ItemUnit tu ON tu.ItemUnitId = f.target_id
ORDER BY f.match_kind, i.ItemCode;

SELECT total = COUNT(*),
       fixable = SUM(CASE WHEN target_id IS NOT NULL THEN 1 ELSE 0 END),
       skipped = SUM(CASE WHEN target_id IS NULL THEN 1 ELSE 0 END)
FROM #Fix;

SELECT tempbomb_to_clear = COUNT(*)
FROM TempBombSales x JOIN ItemUnit iu ON iu.ItemUnitId = x.ItemUnitId
WHERE x.ItemId IS NOT NULL AND x.FactorToBase IS NOT NULL
  AND x.FactorToBase <> iu.FactorToBase AND x.Unit <> iu.Unit
  AND EXISTS (SELECT 1 FROM ItemUnit s WHERE s.ItemId = x.ItemId AND s.FactorToBase = x.FactorToBase);

-- ----------------------------- APPLY (gated) ---------------------------------
IF @Apply = 1
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Rollback backup (idempotent — only new SalesDetailIds appended).
        IF OBJECT_ID('dbo._Fix_BombUnitCrossed_Backup') IS NULL
            CREATE TABLE dbo._Fix_BombUnitCrossed_Backup
            (
                SalesDetailId INT PRIMARY KEY,
                OldItemUnitId INT NULL,
                NewItemUnitId INT NULL,
                FixedAt       DATETIME NOT NULL DEFAULT (GETDATE())
            );

        INSERT INTO dbo._Fix_BombUnitCrossed_Backup (SalesDetailId, OldItemUnitId, NewItemUnitId)
        SELECT f.SalesDetailId, f.cur_id, f.target_id
        FROM #Fix f
        WHERE f.target_id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM dbo._Fix_BombUnitCrossed_Backup b WHERE b.SalesDetailId = f.SalesDetailId);

        -- 2. Re-point ItemUnitId ONLY.
        UPDATE sd
        SET sd.ItemUnitId = f.target_id
        FROM SalesDetail sd
        JOIN #Fix f ON f.SalesDetailId = sd.SalesDetailId
        WHERE f.target_id IS NOT NULL;
        DECLARE @Repointed INT = @@ROWCOUNT;

        -- 3. Clear in-flight crossed TempBombSales draft row(s).
        DELETE x
        FROM TempBombSales x JOIN ItemUnit iu ON iu.ItemUnitId = x.ItemUnitId
        WHERE x.ItemId IS NOT NULL AND x.FactorToBase IS NOT NULL
          AND x.FactorToBase <> iu.FactorToBase AND x.Unit <> iu.Unit
          AND EXISTS (SELECT 1 FROM ItemUnit s WHERE s.ItemId = x.ItemId AND s.FactorToBase = x.FactorToBase);
        DECLARE @TempCleared INT = @@ROWCOUNT;

        -- 4. Verify: no fixed row remains crossed.
        DECLARE @Remaining INT =
            (SELECT COUNT(*)
             FROM SalesDetail sd JOIN ItemUnit iu ON iu.ItemUnitId = sd.ItemUnitId
             JOIN #Fix f ON f.SalesDetailId = sd.SalesDetailId
             WHERE f.target_id IS NOT NULL AND sd.FactorToBase <> iu.FactorToBase AND sd.Unit <> iu.Unit);
        IF @Remaining <> 0
            RAISERROR('Verify failed: %d fixed rows still crossed. Rolling back.', 16, 1, @Remaining);

        PRINT CONCAT('APPLIED. Re-pointed=', @Repointed, '  TempBombCleared=', @TempCleared);
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
ELSE
    PRINT '*** PREVIEW ONLY - no changes made. Review above, then set @Apply = 1 and re-run to apply. ***';

-- Info: exact-match wrong-id crossings still present (0 after apply; = fixable count during preview;
-- legacy name-drift/ambiguous 'SKIPPED' rows are intentionally NOT counted here).
SELECT exact_fixable_wrongid_remaining = COUNT(*)
FROM #Fix f
WHERE f.target_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM SalesDetail sd JOIN ItemUnit iu ON iu.ItemUnitId=sd.ItemUnitId
              WHERE sd.SalesDetailId=f.SalesDetailId AND sd.FactorToBase<>iu.FactorToBase AND sd.Unit<>iu.Unit);

IF OBJECT_ID('tempdb..#Fix') IS NOT NULL DROP TABLE #Fix;
