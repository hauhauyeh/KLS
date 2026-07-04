-- =============================================================================
-- BombUnit_CrossedRows_Fix_rollback.sql
-- Reverses BombUnit_CrossedRows_Fix.sql by restoring the original ItemUnitId on
-- each re-pointed SalesDetail row from the backup table.
--
-- NOTE: the cleared in-flight TempBombSales draft row(s) are NOT restored — they
--   were transient crossed drafts, intentionally deleted. Restoring a bad draft has
--   no value. (If ever needed, re-create the draft from the source order in the app.)
-- =============================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID('dbo._Fix_BombUnitCrossed_Backup') IS NULL
BEGIN
    RAISERROR('Backup table dbo._Fix_BombUnitCrossed_Backup not found — nothing to roll back.', 16, 1);
    RETURN;
END

BEGIN TRY
    BEGIN TRANSACTION;

    -- Restore original ItemUnitId. Only revert rows that still hold the value the fix set
    -- (guards against clobbering a later legitimate edit).
    UPDATE sd
    SET sd.ItemUnitId = b.OldItemUnitId
    FROM SalesDetail sd
    JOIN dbo._Fix_BombUnitCrossed_Backup b ON b.SalesDetailId = sd.SalesDetailId
    WHERE sd.ItemUnitId = b.NewItemUnitId;

    PRINT CONCAT('Rolled back SalesDetail rows: ', @@ROWCOUNT);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH

-- Optional cleanup once rollback is confirmed:
-- DROP TABLE dbo._Fix_BombUnitCrossed_Backup;
