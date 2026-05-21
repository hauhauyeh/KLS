/*
    Permission_AddVendorStatement_rollback.sql
    Reverses Permission_AddVendorStatement.sql by deleting the seeded row.
    Idempotent.
*/

SET NOCOUNT ON;

DELETE FROM dbo.Permission WHERE PermissionId = 6502;

-- Verify (should return zero rows)
SELECT PermissionId, PermissionKey FROM dbo.Permission WHERE PermissionId = 6502;
