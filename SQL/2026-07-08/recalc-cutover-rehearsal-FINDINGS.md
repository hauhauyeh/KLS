# RecalcQAV Cutover — Local Dress-Rehearsal FINDINGS

**Run:** overnight 2026-07-08, unattended, local `KLS_2026` only. **Read this first on wake.**
Plan: `recalc-cutover-rehearsal-plan.md`. Nothing was deployed, committed, patched, or restored while away.

---

## TL;DR / Go–No-Go
- **The cutover + full recost VALIDATES CLEAN on local** — GL balanced, cache matches journal, 104 stranded items
  healed, **0 regressions**, total inventory value change explained.
- **BLOCKER — RESOLVED 2026-07-08:** v1's oversold-recovery used `@Price` as **per-base** while new writers emit
  per-**entered** `@Price` (divide/combine oversold receipts mis-split `@COGS`/`@INV`; ~10×/month, 307 rows / 553 items).
  **Fixed** via the shape-invariant `(@BillQty*@Price)/NULLIF(@Qty,0)` — committed `e60f2c0`
  (`KLS/SQL/2026-07-08/RecalcQAV_recovery_fix.sql`), **deployed** to local (`modify_date` 07:45), and **validated**
  (rollback-wrapped re-recost of 15 non-base oversold items = **0 mismatch** → no-op on historical, correct on new).
- Do **not** backfill BillQty/Price (confirmed unnecessary and harmful).
- **Prod window now uses the FIXED RecalcQAV** (`RecalcQAV_recovery_fix.sql`), not the original v1 body.

---

## 1. Recost
- `EXEC _postmigration_RunRecalcQAV_ForItemCache @RunMode='INVENTORY_HISTORY_ONLY'` — **2,545/2,545 items, 23 min, exit 0.**
- **Cosmetic driver bug — FIXED (`157972b`, deployed):** it printed "Updated item cache rows = 1". That was a
  `@@ROWCOUNT` capture artifact (re-read after the intervening `SELECT` reset it to 1), not a data problem — cache was
  fresh (cache==journal=0). Now captures the UPDATE's `@@ROWCOUNT` into `@UpdatedItemRows`; validated → reports the
  real count.

## 2. Validation (read-only; two harnesses + GL check)
| Check | Result | Verdict |
|---|---|---|
| cache == journal mismatch | **0** | ✅ "all data match" holds |
| invalid states (refined predicate) | 104 → **0** | ✅ all healed |
| Healed (invalid→valid) | 104 | ✅ |
| **NewlyInvalid (valid→broke)** | **0** | ✅ no regressions |
| items changed / unchanged | 119 / 2,426 | ✅ normals untouched |
| total inventory value | $2,176,375 → $2,165,380 (**−$10,995**) | ✅ explained (below) |
| **GL balance — `SUM(CrDeAmount)`** | **0.00 precut AND current** | ✅ ledger balanced |
| **unbalanced transactions (`CrDeAmount`)** | **0 precut AND current** | ✅ recost added no imbalance |

**Why the −$10,995 is correct:** the movers are **oversold items** (negative qty) that were stranded at `$0`
(invalid) and now carry proper **negative** value — e.g. item 7087 (qty −173: $0 → −$5,709), MISC1/2132
(−$816 → −$5,292), item 80 (healed $0 → $1,328). Oversold-with-negative-value is *valid*; stranded-at-$0 was the bug.
`NewlyInvalid=0` confirms no previously-valid item moved into an invalid state.

**GL note:** raw `SUM(Amount)` shifted +$25,955 — a **red herring**. `Amount` is the posting source, not the balance
field; the balanced field is `CrDeAmount` (RecalcQAV maintains it, 12 refs). By `CrDeAmount` the ledger is perfectly
balanced before *and* after (global 0.00, zero unbalanced transactions). The `@INV` −$10,995 / `@COGS` +$26,614 /
`@InvGain/Loss` moves all net out within each transaction.

## 3. BLOCKER — oversold-recovery `@Price` basis (engine, not backfill)
**Confirmed statically** in the deployed `RecalcQAV` (v1) recovery block:
- `@ActualValue = @RecoveredQty * @Price` (recalcqav_2_cutover.sql:265) — `@RecoveredQty` is **base** qty.
- `ABS(@Qty) * (@Price − @LAvgCost)` (~:281) — `@LAvgCost` is per-**base**.
Both assume `@Price` is per-**base**. New writers emit per-**entered** `@Price` (contract:
`txdetail-inv-field-definitions.md` §2). So for a **divide/combine** purchase receipt into an oversold position, the
`@COGS`/`@INV` split is wrong by the unit factor. (Main value line 242 `@BillQty*@Price` and the `@Qty=0` branch
291/296 already use the invariant → those are fine.)

**Exposure (read-only scan of history):** purchases into an oversold position = **8,057 rows**; of those,
**307 used a non-base unit** across **553 items** → **~10/month**. Recurring, not rare. Each is a COGS↔inventory
misallocation (GL stays *balanced* via `CrDeAmount`, but margin/COGS is misstated).

**Fix = the engine rule Howard + reviewer identified** (NOT a backfill; NOT a writer change):
derive base-unit cost from the invariant `(@BillQty * @Price) / NULLIF(@Qty, 0)` inside the recovery, which is
shape-invariant (correct for both old base rows and new entered rows). Proposed patch:
`recalcqav-recovery-invariant-patch.sql` — **PROPOSED, DO NOT DEPLOY, for your review.**

**Why NOT backfill BillQty/Price:** old rows are internally consistent (`oldBillQty × oldPrice` = same value);
one-sided backfill breaks value, two-sided is a risky value-preserving rewrite, and the engine invariant makes both
unnecessary. Historical recost is already correct (historical `@Price` is per-base).

## 4. Not done (deliberately, per safety boundary / 3-strike)
- **No live functional posts** — the bug is proven statically + sized empirically; a live oversold divide-only post
  carries residue risk unattended, so it's deferred to when you're present (rollback-wrapped). Nothing needed it.
- **No patch/deploy/commit/restore** — all held for you.

## 5. Held for Howard (review, then decide)
- **Proposed engine patch:** `recalcqav-recovery-invariant-patch.sql` (review → apply to v1 → retest old+new shape).
- **Uncommitted rehearsal artifacts** (on disk): `recalcqav_1_save_prev.sql`, `recalcqav_2_cutover.sql`,
  `recalc-cutover-afterval.sql`, `recalc-cutover-compare-precut.sql`, this file, the plan. (Backfill already
  committed: `e0a6a71`.)
- **Local state:** cutover is LIVE on local (`RecalcQAV`=v1, `RecalcQAV_prev`=old), recost committed, FactorToBase
  backfilled. `KLS_2026_precut` + `.bak` are the untouched before-image / restore point (for you to use if wanted).

## 6. Suggested prod-window sequence (once the patch is in)
1. Apply the recovery patch to v1; retest old-shape + new-shape recovery rows.
2. Window: deploy SPs → backfill FactorToBase → cutover RecalcQAV (save_prev + v1) → full recost → run both validation
   harnesses (expect: cache==journal=0, 0 new unbalanced tx, invalid drop, value delta = the healing).
3. Sign off the inventory-value delta (the healing is a real GL movement — quantify on prod as we did here: local was
   −$10,995 / 104 items).
