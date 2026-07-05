SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================================================
-- Rollback for LegacyCrossed_CsFix.sql (2026-07-05).
-- Restores ItemUnitId / Unit / FactorToBase for the fixed rows from the backup
-- table dbo._Fix_LegacyCrossed_Backup (created by the forward script at @Apply=1).
-- Run only after the forward apply; the backup table must exist.
-- =============================================================================
IF OBJECT_ID('dbo._Fix_LegacyCrossed_Backup') IS NULL
BEGIN
    RAISERROR('Backup table dbo._Fix_LegacyCrossed_Backup not found - nothing to roll back.', 16, 1);
    RETURN;
END

BEGIN TRAN;

UPDATE sd
SET sd.ItemUnitId   = b.old_ItemUnitId,
    sd.Unit         = b.old_Unit,
    sd.FactorToBase = b.old_FactorToBase
FROM SalesDetail sd
JOIN dbo._Fix_LegacyCrossed_Backup b ON b.SalesDetailId = sd.SalesDetailId;

SELECT rows_restored = @@ROWCOUNT;

COMMIT;
