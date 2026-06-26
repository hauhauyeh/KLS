-- Permission_AddItemAnalysis_rollback.sql
-- Reverses Permission_AddItemAnalysis.sql: drops any role grants for the permission, then the
-- permission row itself. (Grants are dropped first to satisfy the FK; this only removes grants
-- for THIS permission, never other roles' assignments.)
SET NOCOUNT ON;

DELETE rp
FROM RolePermission rp
JOIN Permission p ON p.PermissionId = rp.PermissionId
WHERE p.PermissionKey = 'Report.Item.ItemAnalysis';

DELETE FROM Permission WHERE PermissionKey = 'Report.Item.ItemAnalysis';

PRINT 'Removed Report.Item.ItemAnalysis (6503) and its role grants.';
