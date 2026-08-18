-- Rollback for Permission_AddBasicItem.sql.
-- Removes the Basic Item report page child only.

DELETE rp
FROM dbo.RolePermission AS rp
INNER JOIN dbo.Permission AS p
    ON p.PermissionId = rp.PermissionId
WHERE p.PermissionKey = 'Report.Item.BasicItem';

DELETE FROM dbo.Permission
WHERE PermissionKey = 'Report.Item.BasicItem';
