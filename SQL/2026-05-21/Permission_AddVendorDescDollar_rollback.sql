/*
    Permission_AddVendorDescDollar_rollback.sql
    Reverses Permission_AddVendorDescDollar.sql by deleting the seeded row.
    Idempotent.
*/

SET NOCOUNT ON;

DELETE FROM dbo.Permission WHERE PermissionId = 6503;

-- Verify (should return zero rows)
SELECT PermissionId, PermissionKey FROM dbo.Permission WHERE PermissionId = 6503;
