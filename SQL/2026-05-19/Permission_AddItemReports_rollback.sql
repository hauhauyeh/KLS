/*
    Permission_AddItemReports_rollback.sql
    Reverses Permission_AddItemReports.sql by deleting the two seeded rows.
    Idempotent.
*/

SET NOCOUNT ON;

DELETE FROM dbo.Permission WHERE PermissionId IN (6550, 6551);

-- Verify (should return zero rows)
SELECT PermissionId, PermissionKey FROM dbo.Permission WHERE PermissionId IN (6550, 6551);
