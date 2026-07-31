-- Rollback for Permission_AddWebContent.sql.
-- Removes role grants for the WebContent permissions, then removes the seeded permission rows.

DELETE rp
FROM dbo.RolePermission rp
JOIN dbo.Permission p ON p.PermissionId = rp.PermissionId
WHERE p.PermissionKey IN ('Admin.WebContent', 'Admin.WebContent.List', 'Admin.WebContent.Update');

DELETE FROM dbo.Permission
WHERE PermissionKey IN ('Admin.WebContent.Update', 'Admin.WebContent.List', 'Admin.WebContent');

SELECT PermissionId, PermissionKey
FROM dbo.Permission
WHERE PermissionKey IN ('Admin.WebContent', 'Admin.WebContent.List', 'Admin.WebContent.Update')
ORDER BY PermissionId;
