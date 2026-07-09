-- =============================================================================
-- recalc-cutover-afterval.sql
-- Run AFTER the RecalcQAV cutover + full recost (_postmigration_RunRecalcQAV_ForItemCache
-- @RunMode='INVENTORY_HISTORY_ONLY'). Compares the post-recost state to the
-- pre-cutover baseline in dbo._recalc_cutover_before. Read-only.
-- =============================================================================
USE [KLS_2026];
GO
SET NOCOUNT ON;
GO
DECLARE @INV INT = (SELECT AccountId FROM Account WHERE AccountCode='@INV');

IF OBJECT_ID('tempdb..#after') IS NOT NULL DROP TABLE #after;
SELECT b.ItemId,
       b.J_Qty AS Bef_JQty, b.J_Val AS Bef_JVal, b.J_Avg AS Bef_JAvg, b.C_Val AS Bef_CVal,
       a.J_Qty AS Aft_JQty, a.J_Val AS Aft_JVal, a.J_Avg AS Aft_JAvg,
       it.LCloseQty AS Aft_CQty, it.LInventoryValue AS Aft_CVal, it.LAvgCost AS Aft_CAvg
INTO #after
FROM dbo._recalc_cutover_before b
JOIN dbo.Item it ON it.ItemId = b.ItemId
CROSS APPLY (
    SELECT TOP 1 td.ClosingQty AS J_Qty, td.InventoryValue AS J_Val, td.AverageCost AS J_Avg
    FROM TransactionJournalDetail td JOIN TransactionJournal t ON t.TxId=td.TxId
    WHERE td.AccountId=@INV AND td.ItemId=b.ItemId
    ORDER BY t.TxDate DESC, t.SourceDocOrder DESC, td.TxDetailId DESC
) a;

-- (1) CACHE == JOURNAL after recost  (MUST be 0 -- the core "all data match" invariant)
SELECT [Check] = '1. cache==journal mismatch (must be 0)',
       Cnt = SUM(CASE WHEN ABS(ISNULL(Aft_CVal,0)-ISNULL(Aft_JVal,0))>0.01
                       OR ABS(ISNULL(Aft_CQty,0)-ISNULL(Aft_JQty,0))>0.0001 THEN 1 ELSE 0 END)
FROM #after;

-- (2) TOTAL inventory value: before vs after + delta (the GL movement to explain/sign off)
SELECT [Check]='2. total value', Bef=SUM(Bef_JVal), Aft=SUM(Aft_JVal), Delta=SUM(Aft_JVal)-SUM(Bef_JVal) FROM #after;

-- (3) INVALID states after vs before (357 before -> expect large drop toward 0)
SELECT [Check]='3. invalid states (after)',
   NegVal        = SUM(CASE WHEN Aft_JVal<0 THEN 1 ELSE 0 END),
   ZeroQtyNZVal  = SUM(CASE WHEN Aft_JQty=0 AND Aft_JVal<>0 THEN 1 ELSE 0 END),
   OppositeSign  = SUM(CASE WHEN (Aft_JQty>0 AND Aft_JVal<0) OR (Aft_JQty<0 AND Aft_JVal>0) THEN 1 ELSE 0 END),
   NullVal       = SUM(CASE WHEN Aft_JVal IS NULL OR Aft_JAvg IS NULL THEN 1 ELSE 0 END)
FROM #after;

-- (4) change summary + Healed (was invalid, now valid) + NewlyInvalid (regression: was valid, now invalid).
--     invalid(q,v) = (q>=0 AND v<0) OR (q<0 AND v>0) OR (q=0 AND v<>0)   [oversold q<0 with v<0 is ALLOWED]
SELECT [Check]='4. change summary',
   Changed      = SUM(CASE WHEN ABS(ISNULL(Aft_JVal,0)-ISNULL(Bef_JVal,0))>0.01 THEN 1 ELSE 0 END),
   Unchanged    = SUM(CASE WHEN ABS(ISNULL(Aft_JVal,0)-ISNULL(Bef_JVal,0))<=0.01 THEN 1 ELSE 0 END),
   Healed       = SUM(CASE WHEN     ((ISNULL(Bef_JQty,0)>=0 AND Bef_JVal<0) OR (Bef_JQty<0 AND Bef_JVal>0) OR (Bef_JQty=0 AND Bef_JVal<>0))
                            AND NOT ((ISNULL(Aft_JQty,0)>=0 AND Aft_JVal<0) OR (Aft_JQty<0 AND Aft_JVal>0) OR (Aft_JQty=0 AND Aft_JVal<>0))
                            THEN 1 ELSE 0 END),
   NewlyInvalid = SUM(CASE WHEN NOT ((ISNULL(Bef_JQty,0)>=0 AND Bef_JVal<0) OR (Bef_JQty<0 AND Bef_JVal>0) OR (Bef_JQty=0 AND Bef_JVal<>0))
                            AND     ((ISNULL(Aft_JQty,0)>=0 AND Aft_JVal<0) OR (Aft_JQty<0 AND Aft_JVal>0) OR (Aft_JQty=0 AND Aft_JVal<>0))
                            THEN 1 ELSE 0 END)
FROM #after;

-- (5) TOP 30 value movers (eyeball -- healed stranded items should dominate)
SELECT TOP 30 ItemId, Bef_JQty, Bef_JVal, Aft_JQty, Aft_JVal, ValDelta = Aft_JVal - Bef_JVal
FROM #after ORDER BY ABS(ISNULL(Aft_JVal,0)-ISNULL(Bef_JVal,0)) DESC;

-- (6) items that were VALID before and are now UNCHANGED-expected but moved > $1 (review list)
SELECT TOP 30 ItemId, Bef_JQty, Bef_JVal, Aft_JQty, Aft_JVal, ValDelta = Aft_JVal - Bef_JVal
FROM #after
WHERE Bef_JVal >= 0 AND ISNULL(Bef_JQty,0) > 0
  AND ABS(ISNULL(Aft_JVal,0)-ISNULL(Bef_JVal,0)) > 1
ORDER BY ABS(ISNULL(Aft_JVal,0)-ISNULL(Bef_JVal,0)) DESC;

DROP TABLE #after;

-- (7) GL balance -- ABSOLUTE check (a balanced double-entry ledger has both = 0,
--     regardless of before/after). CrDeAmount is the balance field (Amount is the
--     posting source; do NOT use SUM(Amount) -- it is not zero-sum).
SELECT [Check] = '7. GL balance (must be 0.00 / 0 tx)',
   GlobalCrDeAmount = SUM(CrDeAmount),
   UnbalancedTx = (SELECT COUNT(*) FROM (
       SELECT TxId FROM dbo.TransactionJournalDetail GROUP BY TxId HAVING ABS(SUM(CrDeAmount)) > 0.01) u)
FROM dbo.TransactionJournalDetail;
GO
