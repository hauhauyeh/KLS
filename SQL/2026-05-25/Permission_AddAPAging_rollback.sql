/*
    Permission_AddAPAging_rollback.sql
    Reverses Permission_AddAPAging.sql by deleting the seeded row.
    Idempotent.
*/

SET NOCOUNT ON;

DELETE FROM dbo.Permission WHERE PermissionId = 6054;

-- Verify (should return zero rows)
SELECT PermissionId, PermissionKey FROM dbo.Permission WHERE PermissionId = 6054;
