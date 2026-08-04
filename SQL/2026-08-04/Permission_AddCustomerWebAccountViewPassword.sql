-- Permission seed for admin-only customer web account password reveal.
-- The Admin menu (2000) already exists; this adds the CustomerWebAccount resource and ViewPassword child.
-- Idempotent. Does NOT touch RolePermission; grant access separately through the admin role UI if needed.
-- Deploy: run via sqlcmd -i after approval.

SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Admin.CustomerWebAccount')
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (2750, 'Admin.CustomerWebAccount', 'Customer Web Account', 'Admin', 'CustomerWebAccount', '', 'resource', 2000, 2750, NULL, NULL, 1, SYSDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Admin.CustomerWebAccount.ViewPassword')
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (2751, 'Admin.CustomerWebAccount.ViewPassword', 'View Customer Web Account Password', 'Admin', 'CustomerWebAccount', 'ViewPassword', 'button', 2750, 2751, NULL, NULL, 1, SYSDATETIME());
END

SET IDENTITY_INSERT dbo.Permission OFF;

SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey IN ('Admin.CustomerWebAccount', 'Admin.CustomerWebAccount.ViewPassword')
ORDER BY PermissionId;
