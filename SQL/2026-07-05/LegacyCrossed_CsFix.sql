SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================================================
-- LegacyCrossed_CsFix.sql  (2026-07-05)
-- Fix the ancient "cluster B" crossed SalesDetail rows (GBV / RNBP1 / BENTSSSA,
-- 2024-2025) the bomb remediation deliberately skipped.
--
-- ROOT CAUSE (different from the bomb bug): unit MUTATION over time. The line's
-- ItemUnitId (e.g. GBV 4787) was "pk(2lb)" at FactorToBase=1 in 2024, then later
-- edited to "pk" at FactorToBase=18. The snapshot froze the old truth (factor 1);
-- the id now resolves to the new unit. Phase A.5 immutability now forbids this.
--
-- ARBITER = THE JOURNAL (TxDetail.Qty), NOT SalesDetail.BaseShipQty.
--   BaseShipQty is a derived/stored column that can be stale. What actually posted
--   to inventory is the @INV TransactionJournalDetail.Qty. To be ACCOUNTING-NEUTRAL
--   the fix must repoint ItemUnitId to the unit whose ratio REPRODUCES that posted
--   @INV Qty from ShipQty:  ROUND(ShipQty * MultipleToBase / FactorToBase, 6) = @INV Qty.
--   (Per Howard's rule: fractional posted Qty => non-base unit; whole => base unit.)
--
-- For all current rows the @INV Qty is whole and equals ShipQty, so the reproducing
-- unit is the base cs (factor 1). The script does NOT assume that -- it matches the
-- unit by the journal, and SKIPS any row it cannot reproduce exactly (manual review).
--
-- SAFETY: @Apply gate (0 = preview). Backup dbo._Fix_LegacyCrossed_Backup.
--   Rollback: LegacyCrossed_CsFix_rollback.sql.
-- EXEC: @Apply=0 preview -> review -> @Apply=1 commit.
-- =============================================================================
DECLARE @Apply INT = 0;   -- 0 = preview, 1 = apply

-- Posted @INV base qty per line = the accounting truth (magnitude).
;WITH jrnl AS (
    SELECT tjd.SourceDetailId AS SalesDetailId, jrnl_qty = ABS(SUM(tjd.Qty))
    FROM TransactionJournalDetail tjd
    JOIN Account a ON a.AccountId = tjd.AccountId
    WHERE a.AccountCode = '@INV'
    GROUP BY tjd.SourceDetailId
),
-- Crossed rows: snapshot factor/name disagree with the pointed unit, and a sibling
-- unit matches the snapshot factor (the mutation signature).
crossed AS (
    SELECT sd.SalesDetailId, sd.ItemId, sd.ItemUnitId AS old_id, sd.Unit AS old_unit,
           sd.FactorToBase AS old_factor, sd.ShipQty, sd.BaseShipQty, j.jrnl_qty
    FROM SalesDetail sd
    JOIN ItemUnit iu ON iu.ItemUnitId = sd.ItemUnitId
    JOIN jrnl j ON j.SalesDetailId = sd.SalesDetailId
    WHERE sd.ItemId IS NOT NULL
      AND sd.FactorToBase IS NOT NULL
      AND sd.FactorToBase <> iu.FactorToBase
      AND sd.Unit <> iu.Unit
      AND EXISTS (SELECT 1 FROM ItemUnit s WHERE s.ItemId = sd.ItemId AND s.FactorToBase = sd.FactorToBase)
)
SELECT
    c.SalesDetailId,
    i.ItemCode,
    c.old_id, c.old_unit, c.old_factor,
    c.ShipQty, c.BaseShipQty,
    inv_qty = c.jrnl_qty,                                    -- <- the accounting arbiter (TxDetail)
    baseship_matches_journal = CASE WHEN ROUND(ISNULL(c.BaseShipQty,0),6) = ROUND(c.jrnl_qty,6) THEN 'yes' ELSE 'NO (stale)' END,
    new_id     = tgt.ItemUnitId,
    new_unit   = tgt.Unit,
    new_factor = tgt.FactorToBase,
    -- neutrality proof: reproducing the posted @INV qty from ShipQty via the target unit's ratio
    neutral_reproduced_qty = ROUND(c.ShipQty * tgt.MultipleToBase / NULLIF(tgt.FactorToBase,0), 6),
    target_count = (SELECT COUNT(*) FROM ItemUnit t2 WHERE t2.ItemId = c.ItemId
                    AND ROUND(c.ShipQty * t2.MultipleToBase / NULLIF(t2.FactorToBase,0), 6) = ROUND(c.jrnl_qty,6))
INTO #plan
FROM crossed c
JOIN Item i ON i.ItemId = c.ItemId
-- TARGET = the unit whose ratio reproduces the posted @INV qty (accounting-neutral by construction)
JOIN ItemUnit tgt ON tgt.ItemId = c.ItemId
    AND ROUND(c.ShipQty * tgt.MultipleToBase / NULLIF(tgt.FactorToBase,0), 6) = ROUND(c.jrnl_qty,6);

IF @Apply = 0
BEGIN
    SELECT * FROM #plan ORDER BY ItemCode, SalesDetailId;
    SELECT total = COUNT(*),
           will_fix   = SUM(CASE WHEN target_count = 1 AND new_id <> old_id THEN 1 ELSE 0 END),
           ambiguous_or_none = SUM(CASE WHEN target_count <> 1 THEN 1 ELSE 0 END),
           baseship_stale = SUM(CASE WHEN baseship_matches_journal <> 'yes' THEN 1 ELSE 0 END)
    FROM #plan;
END
ELSE
BEGIN
    BEGIN TRAN;

    IF OBJECT_ID('dbo._Fix_LegacyCrossed_Backup') IS NOT NULL
        DROP TABLE dbo._Fix_LegacyCrossed_Backup;
    SELECT sd.SalesDetailId, sd.ItemUnitId AS old_ItemUnitId, sd.Unit AS old_Unit, sd.FactorToBase AS old_FactorToBase
    INTO dbo._Fix_LegacyCrossed_Backup
    FROM SalesDetail sd
    JOIN #plan p ON p.SalesDetailId = sd.SalesDetailId
    WHERE p.target_count = 1 AND p.new_id <> p.old_id;   -- only unambiguous, journal-reproducible rows

    UPDATE sd
    SET sd.ItemUnitId   = p.new_id,
        sd.Unit         = p.new_unit,
        sd.FactorToBase = p.new_factor
    FROM SalesDetail sd
    JOIN #plan p ON p.SalesDetailId = sd.SalesDetailId
    WHERE p.target_count = 1 AND p.new_id <> p.old_id;

    SELECT rows_fixed = @@ROWCOUNT, backed_up = (SELECT COUNT(*) FROM dbo._Fix_LegacyCrossed_Backup);

    COMMIT;
END

DROP TABLE #plan;
