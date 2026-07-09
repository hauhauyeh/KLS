# Effort-B @INV entered-basis + RecalcQAV cutover — PROD deploy runbook

Rehearsed end-to-end on a prod restore (2026-07-08). Run every step against the **prod DB**
(scripts' `USE [KLS_2026]` is local — set your own DB context).

## Deploy order (maintenance window)

**0. Full DB backup** — your standard process; this is the rollback.

**1. Deploy the SP batch** (idempotent `CREATE OR ALTER`, all together):
- Purchase: `2026-07-07/Purchase_Insert.sql`, `Purchase_PartialUpdate.sql`,
  `VendorPayment_InsertPayNow.sql`, `Shipment_AllocationInventoryClear.sql`
- Sales: `2026-07-07/Sales_Insert.sql`, `Sales_PartialUpdate.sql`, `TempBombSales_Save.sql`
- Driver: `2026-07-08/_postmigration_RunRecalcQAV_ForItemCache_rowcount_fix.sql`
- Schema: `2026-07-08/drop-tjd-landedcost.sql` — drops the unused all-NULL `TransactionJournalDetail.LandedCost`
  (rollback: `drop-tjd-landedcost_rollback.sql`).

**2. Backfill FactorToBase:** run `2026-07-07/factortobase-backfill.sql`. Output must show **mismatch = 0**.
(Rollback: `factortobase-backfill_rollback.sql`.)

**3. RecalcQAV cutover — 2 steps, in this order:**
- **3a.** Run `2026-07-08/recalcqav_1_save_prev.sql` → saves the current prod `RecalcQAV` as `RecalcQAV_prev` (rollback).
- **3b.** Deploy `2026-07-08/RecalcQAV_v2_Final.sql` → `CREATE OR ALTER RecalcQAV` with the fixed engine.
  **This is the cutover.**

**4. Full recost — must run AFTER step 3.** First capture the before-baseline (the validation needs it), then recost:
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
GO
EXEC dbo._postmigration_RunRecalcQAV_ForItemCache @RunMode='INVENTORY_HISTORY_ONLY';
```
(Rehearsal: ~2,545 items / ~23 min — scale for prod.)

**5. Validate:** run `2026-07-08/recalc-cutover-afterval.sql` — self-contained, it compares current vs the
`dbo._recalc_cutover_before` snapshot table from step 4 (same DB; **no separate/backup database needed**). Must show:
- **cache==journal mismatch = 0**
- **NewlyInvalid = 0** (Healed > 0; invalid states drop)
- **GL balance = 0.00 / 0 unbalanced tx** (check 7 — uses `CrDeAmount`, not `Amount`)
- inventory-value delta = the healing (oversold items un-stranded) — **sign off with accounting.**

**6. Cleanup** — after validation passes **and** the value-delta is signed off:
`DROP TABLE dbo._recalc_cutover_before;` (a throwaway comparison table; keep it until sign-off in case you need
to re-run step 5 or re-inspect).

## Rollback
- Whole window: restore the step-0 backup.
- RecalcQAV only: re-deploy `RecalcQAV_prev`, then recost.
- Backfill only: `factortobase-backfill_rollback.sql`.

## Why
Prod RecalcQAV costs sales off `@INV.BillQty`; the sales writers change that field, so RecalcQAV moves to the
`Qty×AvgCost` engine (which also heals stranded inventory values + fixes the oversold-recovery cost). **Do not**
backfill BillQty/Price. Detail: `note-txdetail-inv-field-definitions.md` §2 + `logic-RecalcQAV_Core_v9_Final.md`.
