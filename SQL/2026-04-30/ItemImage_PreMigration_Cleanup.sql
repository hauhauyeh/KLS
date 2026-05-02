-- ItemImage_PreMigration_Cleanup.sql
-- !! EMERGENCY RESET ONLY — do NOT run as part of normal deployment !!
-- This script DESTROYS all migrated image records. Use only when you need
-- to wipe and restart the migration from scratch. Normal reruns are safe
-- without this script (image-level idempotency handles resume).
--
-- This script:
--   1. Reports current ItemImage state
--   2. Deletes migrated ItemImage records (those with ImageIndex > 0 and Has300 flag)
--   3. Resets identity seed if table is empty

SET QUOTED_IDENTIFIER ON;

-- Step 1: Report current state
PRINT '=== Current ItemImage State ===';
SELECT
    COUNT(*) AS TotalRecords,
    SUM(CAST(Has300 AS INT)) AS WithThumbnail,
    SUM(CAST(Has1200 AS INT)) AS With1200,
    SUM(CAST(Has2000 AS INT)) AS With2000
FROM ItemImage;

-- Step 2: Delete all migrated records
PRINT 'Deleting migrated ItemImage records...';
DELETE FROM ItemImage WHERE ImageIndex > 0;

PRINT 'Remaining records:';
SELECT COUNT(*) AS RemainingRecords FROM ItemImage;

-- Step 3: If table is empty, reset identity
IF NOT EXISTS (SELECT 1 FROM ItemImage)
BEGIN
    DBCC CHECKIDENT ('ItemImage', RESEED, 0);
    PRINT 'Identity seed reset to 0.';
END

PRINT 'Pre-migration cleanup completed.';
