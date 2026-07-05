-- =============================================================================
-- Promotion_BogoMaxRewardRepeats_FlipTo0_rollback.sql
-- Rollback for Promotion_BogoMaxRewardRepeats_FlipTo0.sql.
-- Restores BogoMaxRewardRepeats = 1 on the exact 75 promos the fix flipped.
-- Guarded by AND BogoMaxRewardRepeats = 0 so it only reverts rows the fix set
-- (won't clobber a promo an admin has since re-tuned to some other value).
-- =============================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRAN;

    UPDATE Promotion
    SET BogoMaxRewardRepeats = 1
    WHERE BogoMaxRewardRepeats = 0
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

    PRINT CONCAT('Rows restored 0 -> 1: ', @@ROWCOUNT, ' (expected up to 75)');

    COMMIT TRAN;
    PRINT 'Committed.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH
