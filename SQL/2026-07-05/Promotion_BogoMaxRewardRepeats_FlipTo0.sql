-- =============================================================================
-- Promotion_BogoMaxRewardRepeats_FlipTo0.sql
-- Data fix (2026-07-05): flip Promotion.BogoMaxRewardRepeats 1 -> 0 on the 75
-- legacy BOGO promos so their free-reward qty scales with owner qty again.
--
-- Why: BogoMaxRewardRepeats caps how many reward SETS a BOGO promo grants per
-- qualifying line. 0 = unlimited; N > 0 = at most N sets. These 75 promos were
-- created while the promo-editor form defaulted the field to 1 (frontend later
-- fixed the default to 0 in commit 05321dc: "buy 5 get 1 free. if user enter 10
-- get 2 free" -- but existing rows were never backfilled). The =1 cap freezes the
-- reward at one set, so "buy 5 get 1" gives only 1 free even at qty 10/15/...
-- Setting 0 restores qty-proportional rewards (qty 10 -> 2 free, 15 -> 3, ...).
--
-- Scope: DATA ONLY -- one column on 75 rows. No schema / SP change. All 77 promos
-- are PromotionType = 'BOGO_ITEM_CATEGORY'; ids 32 and 77 are already 0 (excluded).
-- Operates on an explicit id list + AND BogoMaxRewardRepeats = 1, so it only ever
-- touches those 75 rows still at 1 (safe + idempotent to re-run).
--
-- Rollback: Promotion_BogoMaxRewardRepeats_FlipTo0_rollback.sql (restores =1 on the
-- same 75 ids).
-- =============================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;

-- Before snapshot (for the deploy log).
SELECT BogoMaxRewardRepeats AS before_value, COUNT(*) AS cnt
FROM Promotion
WHERE PromotionType = 'BOGO_ITEM_CATEGORY'
GROUP BY BogoMaxRewardRepeats
ORDER BY BogoMaxRewardRepeats;

BEGIN TRY
    BEGIN TRAN;

    UPDATE Promotion
    SET BogoMaxRewardRepeats = 0
    WHERE BogoMaxRewardRepeats = 1
      AND PromotionType = 'BOGO_ITEM_CATEGORY'
      AND PromotionId IN (
        1,2,3,4,5,6,7,8,9,10,
        11,12,13,14,15,16,17,18,19,20,
        21,22,23,24,25,26,27,28,29,30,
        31,33,34,35,36,37,38,39,40,41,
        42,43,44,45,46,47,48,49,50,51,
        52,53,54,55,56,57,58,59,60,61,
        62,63,64,65,66,67,68,69,70,71,
        72,73,74,75,76
      );

    PRINT CONCAT('Rows flipped 1 -> 0: ', @@ROWCOUNT, ' (expected 75)');

    COMMIT TRAN;
    PRINT 'Committed.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH

-- After verify: expect 0 rows remaining at 1, 77 at 0.
SELECT BogoMaxRewardRepeats AS after_value, COUNT(*) AS cnt
FROM Promotion
WHERE PromotionType = 'BOGO_ITEM_CATEGORY'
GROUP BY BogoMaxRewardRepeats
ORDER BY BogoMaxRewardRepeats;
