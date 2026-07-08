-- =============================================================================
-- recalc-cutover-compare-precut.sql
-- Deep before/after comparison of the RecalcQAV cutover + full recost, using the
-- frozen side-by-side copy KLS_2026_precut as the authoritative "before".
-- Run AFTER the recost. Read-only. (Complements recalc-cutover-afterval.sql,
-- which uses the _recalc_cutover_before snapshot.)
-- =============================================================================
USE [KLS_2026];
GO
SET NOCOUNT ON;
GO
DECLARE @INV  INT = (SELECT AccountId FROM dbo.Account WHERE AccountCode='@INV');
DECLARE @COGS INT = (SELECT AccountId FROM dbo.Account WHERE AccountCode='@COGS');

-- Per-item Item-cache: before (precut) vs after (current) for the @INV items.
IF OBJECT_ID('tempdb..#cmp') IS NOT NULL DROP TABLE #cmp;
SELECT cur.ItemId,
       Bef_Qty = pre.LCloseQty, Bef_Val = pre.LInventoryValue, Bef_Avg = pre.LAvgCost,
       Aft_Qty = cur.LCloseQty, Aft_Val = cur.LInventoryValue, Aft_Avg = cur.LAvgCost
INTO #cmp
FROM dbo.Item cur
JOIN KLS_2026_precut.dbo.Item pre ON pre.ItemId = cur.ItemId
WHERE EXISTS (SELECT 1 FROM dbo.TransactionJournalDetail td WHERE td.ItemId=cur.ItemId AND td.AccountId=@INV);

-- inv(q,v) = invalid predicate: (q>=0 AND v<0) OR (q<0 AND v>0) OR (q=0 AND v<>0)  [oversold q<0,v<0 allowed]

-- (1) headline: totals + delta + how many items changed / healed / regressed
SELECT [Section]='1. cache totals',
   Bef_Total = SUM(Bef_Val), Aft_Total = SUM(Aft_Val), Delta = SUM(Aft_Val)-SUM(Bef_Val),
   Changed   = SUM(CASE WHEN ABS(ISNULL(Aft_Val,0)-ISNULL(Bef_Val,0))>0.01 THEN 1 ELSE 0 END),
   Healed    = SUM(CASE WHEN     ((ISNULL(Bef_Qty,0)>=0 AND Bef_Val<0) OR (Bef_Qty<0 AND Bef_Val>0) OR (Bef_Qty=0 AND Bef_Val<>0))
                         AND NOT ((ISNULL(Aft_Qty,0)>=0 AND Aft_Val<0) OR (Aft_Qty<0 AND Aft_Val>0) OR (Aft_Qty=0 AND Aft_Val<>0)) THEN 1 ELSE 0 END),
   NewlyBad  = SUM(CASE WHEN NOT ((ISNULL(Bef_Qty,0)>=0 AND Bef_Val<0) OR (Bef_Qty<0 AND Bef_Val>0) OR (Bef_Qty=0 AND Bef_Val<>0))
                         AND     ((ISNULL(Aft_Qty,0)>=0 AND Aft_Val<0) OR (Aft_Qty<0 AND Aft_Val>0) OR (Aft_Qty=0 AND Aft_Val<>0)) THEN 1 ELSE 0 END)
FROM #cmp;

-- (2) invalid-state counts before vs after
SELECT [Section]='2. invalid counts',
   Bef_Invalid = SUM(CASE WHEN (ISNULL(Bef_Qty,0)>=0 AND Bef_Val<0) OR (Bef_Qty<0 AND Bef_Val>0) OR (Bef_Qty=0 AND Bef_Val<>0) THEN 1 ELSE 0 END),
   Aft_Invalid = SUM(CASE WHEN (ISNULL(Aft_Qty,0)>=0 AND Aft_Val<0) OR (Aft_Qty<0 AND Aft_Val>0) OR (Aft_Qty=0 AND Aft_Val<>0) THEN 1 ELSE 0 END)
FROM #cmp;

-- (3) "all data match": current Item cache == current journal latest @INV row (MUST be 0 mismatch)
SELECT [Section]='3. cache==journal (must be 0)',
   Mismatch = SUM(CASE WHEN ABS(ISNULL(c.LInventoryValue,0)-ISNULL(j.InventoryValue,0))>0.01
                        OR ABS(ISNULL(c.LCloseQty,0)-ISNULL(j.ClosingQty,0))>0.0001 THEN 1 ELSE 0 END)
FROM dbo.Item c
JOIN #cmp m ON m.ItemId=c.ItemId
CROSS APPLY (SELECT TOP 1 td.ClosingQty, td.InventoryValue FROM dbo.TransactionJournalDetail td
   JOIN dbo.TransactionJournal t ON t.TxId=td.TxId
   WHERE td.AccountId=@INV AND td.ItemId=c.ItemId
   ORDER BY t.TxDate DESC, t.SourceDocOrder DESC, td.TxDetailId DESC) j;

-- (4) GL-level Amount movement on @INV and @COGS rows (precut vs current), for @INV items.
SELECT [Section]='4. GL Amount totals',
   INV_Bef  = (SELECT SUM(td.Amount) FROM KLS_2026_precut.dbo.TransactionJournalDetail td WHERE td.AccountId=@INV),
   INV_Aft  = (SELECT SUM(td.Amount) FROM dbo.TransactionJournalDetail td WHERE td.AccountId=@INV),
   COGS_Bef = (SELECT SUM(td.Amount) FROM KLS_2026_precut.dbo.TransactionJournalDetail td WHERE td.AccountId=@COGS),
   COGS_Aft = (SELECT SUM(td.Amount) FROM dbo.TransactionJournalDetail td WHERE td.AccountId=@COGS);

-- (5) TOP 30 value movers (healed stranded items should dominate)
SELECT TOP 30 ItemId, Bef_Qty, Bef_Val, Aft_Qty, Aft_Val, ValDelta = Aft_Val - Bef_Val
FROM #cmp ORDER BY ABS(ISNULL(Aft_Val,0)-ISNULL(Bef_Val,0)) DESC;

-- (6) REGRESSIONS to eyeball: items VALID before that moved > $1 (should be explainable, not surprises)
SELECT TOP 40 ItemId, Bef_Qty, Bef_Val, Aft_Qty, Aft_Val, ValDelta = Aft_Val - Bef_Val
FROM #cmp
WHERE NOT ((ISNULL(Bef_Qty,0)>=0 AND Bef_Val<0) OR (Bef_Qty<0 AND Bef_Val>0) OR (Bef_Qty=0 AND Bef_Val<>0))
  AND ABS(ISNULL(Aft_Val,0)-ISNULL(Bef_Val,0)) > 1
ORDER BY ABS(ISNULL(Aft_Val,0)-ISNULL(Bef_Val,0)) DESC;

DROP TABLE #cmp;
GO
