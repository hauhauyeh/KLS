-- =============================================================================
-- Phase 2 migration — promo free-row data model consolidation
-- See d:\KLS\AI-Development\plan\promo-centralization.md for full rationale.
--
-- Purges legacy promo reward rows that used the SourceTempSalesId marker.
-- We do NOT try to migrate them to the new shape because the old rows never
-- persisted PromotionBogoId, so TempSalesPromo links can't be reconstructed.
-- Migrating without links would leave orphan rewards that admin can't
-- toggle off via the new path.
--
-- Side effect: admins with in-flight carts at cutover lose any in-flight
-- promo rewards. Acceptable because ApplyPromotion already performs a full
-- reset each time it runs — admin re-applies on next interaction.
--
-- Run this alongside the Phase 2 code deploy, inside a transaction, after a
-- full DB backup so rollback can restore the deleted rows.
-- =============================================================================

BEGIN TRANSACTION;

DECLARE @legacyRowCount INT;
SELECT @legacyRowCount = COUNT(*) FROM TempSales WHERE SourceTempSalesId IS NOT NULL;
PRINT CONCAT('Legacy promo reward rows to purge: ', @legacyRowCount);

DELETE FROM TempSales WHERE SourceTempSalesId IS NOT NULL;

-- Sanity check: no legacy-marker rows remain.
IF EXISTS (SELECT 1 FROM TempSales WHERE SourceTempSalesId IS NOT NULL)
BEGIN
    PRINT 'ERROR: legacy rows still present after purge — rolling back.';
    ROLLBACK TRANSACTION;
END
ELSE
BEGIN
    PRINT 'Purge complete.';
    COMMIT TRANSACTION;
END
