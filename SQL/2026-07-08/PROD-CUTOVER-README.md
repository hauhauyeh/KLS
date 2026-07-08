# Effort-B @INV entered-basis + RecalcQAV cutover — PROD deploy runbook

Rehearsed end-to-end on a recent-prod restore (2026-07-08). Full rationale + validation
evidence: `recalc-cutover-rehearsal-FINDINGS.md`. Run every step against the **prod DB**
(the scripts' `USE [KLS_2026]` is local — set your own DB context).

## Deploy order (server down / maintenance window)

**0. Backups (before anything):**
- **Full DB backup** — the primary rollback: `BACKUP DATABASE <prod> TO DISK='…\prod_precut.bak' WITH INIT;`
- **Recommended — a side-by-side copy for before/after comparison.** Restore that same `.bak` as a second DB
  (e.g. `<prod>_precut`) so you can diff any table pre-vs-post and run the deep `recalc-cutover-compare-precut.sql`:
  ```sql
  RESTORE DATABASE [<prod>_precut] FROM DISK='…\prod_precut.bak'
    WITH MOVE '<logical_data_name>' TO '…\<prod>_precut.mdf',
         MOVE '<logical_log_name>'  TO '…\<prod>_precut_log.ldf', RECOVERY;
  ```
  (The `_recalc_cutover_before` snapshot table in step 4 covers pass/fail validation by itself; this copy adds
  full-DB forensics + a second safety net.)

**1. Deploy the SP batch** (idempotent `CREATE OR ALTER`; deploy all together):
- Purchase: `2026-07-07/Purchase_Insert.sql`, `Purchase_PartialUpdate.sql`,
  `VendorPayment_InsertPayNow.sql`, `Shipment_AllocationInventoryClear.sql`
- Sales: `2026-07-07/Sales_Insert.sql`, `Sales_PartialUpdate.sql`, `TempBombSales_Save.sql`
- Driver: `2026-07-08/_postmigration_RunRecalcQAV_ForItemCache_rowcount_fix.sql`
- Schema (independent, unused all-NULL column): `2026-07-08/drop-tjd-landedcost.sql` — drops
  `TransactionJournalDetail.LandedCost` (guard aborts if any non-NULL). Rollback: `drop-tjd-landedcost_rollback.sql`.

**2. Backfill FactorToBase** (data migration, batched, self-validating):
- `2026-07-07/factortobase-backfill.sql` — check output: **mismatch = 0**. Rollback: `factortobase-backfill_rollback.sql`.

**3. RecalcQAV cutover** — replace the `RecalcQAV` proc body with the new engine. **Two steps, in this order:**

- **3a — back up the current engine.** Run `2026-07-08/recalcqav_1_save_prev.sql`. It copies the *currently-deployed*
  prod `RecalcQAV` to `dbo.RecalcQAV_prev` (fast proc-level rollback; generic — it captures whatever body is live, so
  it works on prod as-is). Confirm `RecalcQAV_prev` now exists.
- **3b — deploy the fixed engine AS `RecalcQAV`.** Deploy `2026-07-08/RecalcQAV_recovery_fix.sql`. It is
  `CREATE OR ALTER PROCEDURE [dbo].[RecalcQAV]` carrying the corrected `@Qty`-based body (with the oversold-recovery
  `(BillQty×Price)/Qty` fix). **This IS the cutover** — after it runs, `dbo.RecalcQAV` is the new engine.
  - ⚠️ Deploy **`RecalcQAV_recovery_fix.sql`** — **NOT** `2026-07-07/RecalcQAV-v1_final.sql` (superseded; has the bug).
  - Verify: `SELECT modify_date FROM sys.objects WHERE name='RecalcQAV';` advanced, and the body contains `@UnitCostBase`.

> ⚠️ **ORDERING — step 3 must finish BEFORE step 4.** The recost has to run on the *already-fixed* engine. If you
> recost first and deploy the fix after, a small error stays live on oversold Receive≠Final rows (the rehearsal saw
> $23.92; see FINDINGS). Always: **cutover (3) → recost (4).**

*There is no single "cutover SP." `RecalcQAV` is the proc being replaced (by 3b); `_postmigration_RunRecalcQAV_ForItemCache`
(step 4) is the driver SP that recosts the whole catalog with the new `RecalcQAV`.*

**4. Full recost:**
- Capture the BEFORE baseline first (needed by the validation harness):
  ```sql
  IF OBJECT_ID('dbo._recalc_cutover_before') IS NOT NULL DROP TABLE dbo._recalc_cutover_before;
  DECLARE @INV INT=(SELECT AccountId FROM Account WHERE AccountCode='@INV');
  SELECT i.ItemId, x.ClosingQty J_Qty, x.InventoryValue J_Val, x.AverageCost J_Avg,
         it.LCloseQty C_Qty, it.LInventoryValue C_Val, it.LAvgCost C_Avg
  INTO dbo._recalc_cutover_before
  FROM (SELECT DISTINCT ItemId FROM TransactionJournalDetail WHERE AccountId=@INV AND ItemId IS NOT NULL) i
  JOIN dbo.Item it ON it.ItemId=i.ItemId
  CROSS APPLY (SELECT TOP 1 td.ClosingQty,td.InventoryValue,td.AverageCost
     FROM TransactionJournalDetail td JOIN TransactionJournal t ON t.TxId=td.TxId
     WHERE td.AccountId=@INV AND td.ItemId=i.ItemId
     ORDER BY t.TxDate DESC,t.SourceDocOrder DESC,td.TxDetailId DESC) x;
  ```
- `EXEC dbo._postmigration_RunRecalcQAV_ForItemCache @RunMode='INVENTORY_HISTORY_ONLY';`
  (local: ~2,545 items / 23 min — scale for prod.)

**5. Validate:** run `2026-07-08/recalc-cutover-afterval.sql`. Pass criteria:
- **cache==journal mismatch = 0**
- **NewlyInvalid = 0** (no previously-valid item broke); invalid states drop, Healed > 0
- **GL balance = 0.00 / 0 unbalanced tx** (check 7 — `CrDeAmount`, NOT `Amount`)
- total inventory value delta = the healing (oversold items un-stranded) — **sign this off with accounting**.
- (Optional deep forensics: restore a side-by-side `*_precut` copy and run `recalc-cutover-compare-precut.sql`.)

## Rollback
- Whole window: restore the step-0 backup.
- RecalcQAV only: re-deploy `RecalcQAV_prev` (then recost).
- Backfill only: `factortobase-backfill_rollback.sql`.

## Why (one line)
Prod RecalcQAV costs sales off `@INV.BillQty`; the entered-basis sales writers change that field, so
RecalcQAV must move to the `Qty×AvgCost` (v1) engine — which also heals stranded inventory values and fixes
the oversold-recovery base-cost (`(BillQty×Price)/Qty`). Do **not** backfill BillQty/Price (unnecessary + risky).
