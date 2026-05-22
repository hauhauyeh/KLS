/*
    Permission_AddItemVendorAnalysis_rollback.sql
    Reverses Permission_AddItemVendorAnalysis.sql by deleting the seeded row.
    Idempotent.
*/

SET NOCOUNT ON;

DELETE FROM dbo.Permission WHERE PermissionId = 6552;

-- Verify (should return zero rows)
SELECT PermissionId, PermissionKey FROM dbo.Permission WHERE PermissionId = 6552;
