/* =====================================================================
   RecalcQAV-v1 verification harness  (run AFTER deploying RecalcQAV-v1)
   DEV DB: KLS_2026. Recosts a few items from inception (2024-01-01) and
   checks the resulting @INV ledger for validity.

   SAFE BY DEFAULT: wrapped in a transaction that ROLLBACKs at the end, so
   nothing is permanently written. Inspect the result grids, then either
   leave the ROLLBACK (discard) or change it to COMMIT to keep the recost.
   ===================================================================== */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @InvAccountId INT =
    (SELECT AccountId FROM dbo.Account WHERE AccountCode = '@INV');

-- Test items: the three diagnostic cases + two "normal" items (should be identity).
DECLARE @items TABLE (ItemId INT, Label NVARCHAR(50));
INSERT INTO @items (ItemId, Label) VALUES
    (1377, 'OJF  free-receipt then oversold'),
    (2132, 'MISC1 oversold (Qty<0)'),
    (1527, 'RAD  value-stranded-at-zero');
-- add two currently-normal items (positive stock, valid) as identity controls
INSERT INTO @items (ItemId, Label)
SELECT TOP (2) td.ItemId, 'NORMAL control'
FROM dbo.TransactionJournalDetail td
JOIN dbo.TransactionJournal t ON t.TxId = td.TxId
WHERE td.AccountId = @InvAccountId AND td.ItemId IS NOT NULL
      AND td.ClosingQty > 0 AND td.InventoryValue > 0
      AND ABS(td.AverageCost - td.InventoryValue/NULLIF(td.ClosingQty,0)) <= 0.01
      AND td.ItemId NOT IN (1377,2132,1527)
GROUP BY td.ItemId
ORDER BY td.ItemId;

-- ---- BEFORE: latest @INV row per test item ----
SELECT i.ItemId, i.Label,
       b.ClosingQty AS Bef_Qty, b.InventoryValue AS Bef_Val, b.AverageCost AS Bef_Avg
INTO #before
FROM @items i
OUTER APPLY (
    SELECT TOP 1 td.ClosingQty, td.InventoryValue, td.AverageCost
    FROM dbo.TransactionJournalDetail td
    JOIN dbo.TransactionJournal t ON t.TxId = td.TxId
    WHERE td.AccountId = @InvAccountId AND td.ItemId = i.ItemId
    ORDER BY t.TxDate DESC, t.SourceDocOrder DESC, td.TxDetailId DESC
) b;

-- ---- RUN: recost each item from inception ----
DECLARE @ItemId INT, @c DECIMAL(18,6), @a DECIMAL(18,6), @v DECIMAL(18,6);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT ItemId FROM @items;
OPEN cur; FETCH NEXT FROM cur INTO @ItemId;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @c = 0; SET @a = 0; SET @v = 0;
    EXEC [dbo].[RecalcQAV-v1] @ItemId, '2024-01-01', @c OUTPUT, @a OUTPUT, @v OUTPUT;
    FETCH NEXT FROM cur INTO @ItemId;
END
CLOSE cur; DEALLOCATE cur;

/* ============ VALIDATION ============ */

-- (1) BEFORE vs AFTER latest state (normal controls should be identical;
--     OJF should heal: AvgCost no longer the distorted/ frozen number).
SELECT i.ItemId, i.Label,
       bf.Bef_Qty, bf.Bef_Val, bf.Bef_Avg,
       af.ClosingQty AS Aft_Qty, af.InventoryValue AS Aft_Val, af.AverageCost AS Aft_Avg
FROM @items i
JOIN #before bf ON bf.ItemId = i.ItemId
OUTER APPLY (
    SELECT TOP 1 td.ClosingQty, td.InventoryValue, td.AverageCost
    FROM dbo.TransactionJournalDetail td
    JOIN dbo.TransactionJournal t ON t.TxId = td.TxId
    WHERE td.AccountId = @InvAccountId AND td.ItemId = i.ItemId
    ORDER BY t.TxDate DESC, t.SourceDocOrder DESC, td.TxDetailId DESC
) af
ORDER BY i.ItemId;

-- (2) INVALID-STATE SCAN over every recosted @INV row for the test items.
--     Expect all counts = 0 (except intentionally-allowed negative oversold).
SELECT i.ItemId, i.Label,
    NullRows        = SUM(CASE WHEN td.ClosingQty IS NULL OR td.InventoryValue IS NULL
                                 OR td.AverageCost IS NULL OR td.Amount IS NULL THEN 1 ELSE 0 END),
    OppositeSign    = SUM(CASE WHEN (td.ClosingQty>0 AND td.InventoryValue<0)
                                 OR (td.ClosingQty<0 AND td.InventoryValue>0) THEN 1 ELSE 0 END),
    ZeroQty_NZValue = SUM(CASE WHEN td.ClosingQty=0 AND td.InventoryValue<>0 THEN 1 ELSE 0 END),
    ZeroQty_NZAvg   = SUM(CASE WHEN td.ClosingQty=0 AND td.AverageCost<>0 THEN 1 ELSE 0 END),
    AvgMismatch     = SUM(CASE WHEN td.ClosingQty<>0
                             AND ABS(td.AverageCost - td.InventoryValue/NULLIF(td.ClosingQty,0)) > 0.01
                             THEN 1 ELSE 0 END),
    Rows            = COUNT(*)
FROM @items i
JOIN dbo.TransactionJournalDetail td ON td.ItemId = i.ItemId AND td.AccountId = @InvAccountId
GROUP BY i.ItemId, i.Label
ORDER BY i.ItemId;

-- (3) OJF ledger detail (eyeball): free gal should cost 0, sale-from-zero uses
--     RecentCost (52.40 base-unit), value should NOT strand negative on every row.
SELECT TOP 40 t.TxDate, t.SourceDocType, t.SourceDocNumber AS DocNo,
       td.Qty, td.Price, td.BillQty, td.Amount,
       td.ClosingQty AS CloQty, td.InventoryValue AS InvVal, td.AverageCost AS AvgCost
FROM dbo.TransactionJournalDetail td
JOIN dbo.TransactionJournal t ON t.TxId = td.TxId
JOIN dbo.Item it ON it.ItemId = td.ItemId AND it.ItemCode = 'OJF'
WHERE td.AccountId = @InvAccountId
ORDER BY t.TxDate DESC, t.SourceDocOrder DESC, td.TxDetailId DESC;

-- (4) GL tie-out spot check: for each test item, does the @INV running
--     InventoryValue on the last row equal SUM(Amount) across its @INV rows?
--     (should match; a mismatch means an unabsorbed normalize leak)
SELECT i.ItemId, i.Label,
       SumAmount   = SUM(td.Amount),
       LastInvVal  = MAX(CASE WHEN rn=1 THEN td.InventoryValue END),
       Diff        = SUM(td.Amount) - MAX(CASE WHEN rn=1 THEN td.InventoryValue END)
FROM @items i
JOIN (
    SELECT td.*, ROW_NUMBER() OVER (PARTITION BY td.ItemId
              ORDER BY t.TxDate DESC, t.SourceDocOrder DESC, td.TxDetailId DESC) rn
    FROM dbo.TransactionJournalDetail td
    JOIN dbo.TransactionJournal t ON t.TxId = td.TxId
    WHERE td.AccountId = @InvAccountId
) td ON td.ItemId = i.ItemId
GROUP BY i.ItemId, i.Label
ORDER BY i.ItemId;

DROP TABLE #before;

-- Discard by default. Change to COMMIT TRAN to keep the recost.
ROLLBACK TRAN;
