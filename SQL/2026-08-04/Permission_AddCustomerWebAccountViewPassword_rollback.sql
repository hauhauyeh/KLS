-- Rollback for Permission_AddCustomerWebAccountViewPassword.sql.
-- Removes role grants for the CustomerWebAccount permissions, then removes the seeded permission rows.

DELETE rp
FROM dbo.RolePermission rp
JOIN dbo.Permission p ON p.PermissionId = rp.PermissionId
WHERE p.PermissionKey IN ('Admin.CustomerWebAccount', 'Admin.CustomerWebAccount.ViewPassword');

DELETE FROM dbo.Permission
WHERE PermissionKey IN ('Admin.CustomerWebAccount.ViewPassword', 'Admin.CustomerWebAccount');

SELECT PermissionId, PermissionKey
FROM dbo.Permission
WHERE PermissionKey IN ('Admin.CustomerWebAccount', 'Admin.CustomerWebAccount.ViewPassword')
ORDER BY PermissionId;
