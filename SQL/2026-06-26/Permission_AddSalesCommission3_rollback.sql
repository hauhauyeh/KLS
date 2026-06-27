-- Permission_AddSalesCommission3_rollback.sql
-- Reverses Permission_AddSalesCommission3.sql: drops any role grants for the permission, then the
-- permission row itself. (Grants are dropped first to satisfy the FK; this only removes grants
-- for THIS permission, never other roles' assignments.)
SET NOCOUNT ON;

DELETE rp
FROM RolePermission rp
JOIN Permission p ON p.PermissionId = rp.PermissionId
WHERE p.PermissionKey = 'Report.Sales.SalesCommission3';

DELETE FROM Permission WHERE PermissionKey = 'Report.Sales.SalesCommission3';

PRINT 'Removed Report.Sales.SalesCommission3 (6417) and its role grants.';
