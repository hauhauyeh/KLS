-- ============================================================================
-- TxDetail_FixAmountSign_292_310_rollback.sql (2026-07-17)
--
-- Rollback for TxDetail_FixAmountSign_292_310.sql.
-- The forward fix set Amount = CrDeAmount * -1 on rows that previously had
-- Amount = CrDeAmount (CrDeAmount was never modified), so restoring the
-- original state is the exact inverse: Amount = CrDeAmount.
--
-- WARNING: this restores the WRONG-sign legacy data. Only run it if the
-- forward fix must be reverted wholesale. Rows written correctly by FIXED
-- versions of the SPs after the data fix would also match this WHERE and be
-- flipped to the legacy (wrong) sign -- so run this only before redeploying
-- the corrected SPs, or accept that post-fix rows revert to legacy convention.
-- ============================================================================
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;

UPDATE dbo.TransactionJournalDetail
SET Amount = CrDeAmount
WHERE AccountId IN (292, 310)
  AND Amount = CrDeAmount * -1
  AND CrDeAmount <> 0;

SELECT RowsReverted = @@ROWCOUNT;

COMMIT TRANSACTION;
