-- ============================================================================
-- TxDetail_FixAmountSign_292_310.sql (2026-07-17)
--
-- Fix: TransactionJournalDetail.Amount stored with the WRONG SIGN for
--   AccountId 292 (@IDG  - SALES DISCOUNT GIVEN, contra-income, IsAccountDebit=1)
--   AccountId 310 (@ICREDIT - CUSTOMER CREDIT,   contra-income, IsAccountDebit=1)
--
-- Convention (documented in CustomerPayment_Insert Phase 9):
--   Amount     = business increase(+)/decrease(-) of the account  (source of truth)
--   CrDeAmount = derived debit/credit storage via Fn_Adjust_CrDeAmount / Fn_CrDeAmount
-- For a debit-type account (IsAccountDebit=1) the invariant is:
--   Amount > 0  ->  CrDeAmount = -ABS(Amount)   (debit)
--   Amount < 0  ->  CrDeAmount = +ABS(Amount)   (credit)
-- i.e. Amount must ALWAYS equal  CrDeAmount * -1.
--
-- Root cause (CrDeAmount is CORRECT everywhere; only Amount is wrong):
--   1. CustomerPayment_Insert, section "19B. Post discount-given line":
--      inserts  Amount = @Amount * -1  (should be @Amount).           -> 292 rows
--   2. Sales_Insert, Section 13 (NonInventory + Inventory sales rows):
--      CrDeAmount from ABS(ExtTotal) but Amount = raw signed ExtTotal
--      (negative when the line routes to @ICREDIT).                   -> 310 rows
--   3. Sales_PartialUpdate, I/U branches: same pattern -- @ABSAmount feeds
--      Fn_Adjust_CrDeAmount but Amount = @ExtTotal (signed).          -> 310 rows
--
-- Verified against KLS-2026 on 2026-07-17 (3,874 affected rows):
--   * every row on 292/310 has ABS(Amount) = ABS(CrDeAmount), none zero/null
--   * every row has Amount = CrDeAmount (impossible for a correct debit-type row,
--     where Amount = -CrDeAmount) -- so the WHERE below hits exactly the bad rows
--   * all rows belong to SourceDocType 'Sales' / 'Customer Payment'
--   Breakdown: 292 Customer Payment: 572 | 292 Sales: 10 | 310 Sales: 3,292
--
-- Safe to re-run: after the fix Amount <> CrDeAmount, so the UPDATE matches 0 rows.
-- CrDeAmount is untouched -> journal balance (SUM(CrDeAmount)=0 per TxId) unchanged.
-- Rollback: TxDetail_FixAmountSign_292_310_rollback.sql
-- ============================================================================
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

-- Pre-check: expected bad-row count
SELECT BadRowsBefore = COUNT(*)
FROM dbo.TransactionJournalDetail
WHERE AccountId IN (292, 310)
  AND Amount = CrDeAmount
  AND CrDeAmount <> 0;

UPDATE dbo.TransactionJournalDetail
SET Amount = CrDeAmount * -1
WHERE AccountId IN (292, 310)
  AND Amount = CrDeAmount
  AND CrDeAmount <> 0;

SELECT RowsFixed = @@ROWCOUNT;

-- Post-check: must both return 0
SELECT BadRowsAfter = COUNT(*)
FROM dbo.TransactionJournalDetail
WHERE AccountId IN (292, 310)
  AND Amount = CrDeAmount
  AND CrDeAmount <> 0;

SELECT InvariantViolationsAfter = COUNT(*)
FROM dbo.TransactionJournalDetail
WHERE AccountId IN (292, 310)
  AND Amount <> CrDeAmount * -1;

COMMIT TRANSACTION;
