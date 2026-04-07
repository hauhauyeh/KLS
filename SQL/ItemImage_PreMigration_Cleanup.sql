-- ItemImage_PreMigration_Cleanup.sql
-- !! EMERGENCY RESET ONLY — do NOT run as part of normal deployment !!
-- This script DESTROYS all migrated image records. Use only when you need
-- to wipe and restart the migration from scratch. Normal reruns are safe
-- without this script (image-level idempotency handles resume).
--
-- This script:
--   1. Reports current ItemImage state
--   2. Deletes all migrated ItemImage records (those with per-item folder paths)
--   3. Resets identity seed if table is empty
-- The old v19 records (flat path like /Images/items/47.webp) are preserved.

SET QUOTED_IDENTIFIER ON;

-- Step 1: Report current state
PRINT '=== Current ItemImage State ===';
SELECT
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN ThumbnailPath LIKE '%/Images/items/%/%' THEN 1 ELSE 0 END) AS MigratedRecords,
    SUM(CASE WHEN ThumbnailPath NOT LIKE '%/Images/items/%/%' OR ThumbnailPath IS NULL THEN 1 ELSE 0 END) AS OldRecords
FROM ItemImage;

-- Step 2: Delete migrated records (per-item folder pattern has TWO slashes after /items/)
-- Old records like /Images/items/47.webp have only ONE level — preserved.
PRINT 'Deleting migrated ItemImage records...';
DELETE FROM ItemImage WHERE ThumbnailPath LIKE '/Images/items/%/%-300.png';

PRINT 'Remaining records:';
SELECT COUNT(*) AS RemainingRecords FROM ItemImage;

-- Step 3: If table is empty, reset identity
IF NOT EXISTS (SELECT 1 FROM ItemImage)
BEGIN
    DBCC CHECKIDENT ('ItemImage', RESEED, 0);
    PRINT 'Identity seed reset to 0.';
END

PRINT 'Pre-migration cleanup completed.';
