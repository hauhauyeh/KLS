/*
    Permission_AddARAging_rollback.sql
    2026-06-09

    Reverses Permission_AddARAging.sql by removing the Report.AR.Aging
    permission row (6103). Idempotent.
*/

SET NOCOUNT ON;
DELETE FROM dbo.Permission WHERE PermissionId = 6103;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey LIKE 'Report.AR%'
ORDER BY SortOrder;
