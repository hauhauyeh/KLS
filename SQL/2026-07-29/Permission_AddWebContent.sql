-- Permission seed for the admin Web Home Content screen.
-- The Admin menu (2000) already exists; this adds the WebContent resource and List/Update children.
-- Idempotent. Does NOT touch RolePermission; grant access separately through the admin role UI.
-- Deploy: run via sqlcmd -i after approval.

SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Admin.WebContent')
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (2700, 'Admin.WebContent', 'Web Content', 'Admin', 'WebContent', '', 'resource', 2000, 2700, NULL, NULL, 1, SYSDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Admin.WebContent.List')
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (2701, 'Admin.WebContent.List', 'View Web Home Content', 'Admin', 'WebContent', 'List', 'page', 2700, 2701, NULL, NULL, 1, SYSDATETIME());
END

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Admin.WebContent.Update')
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (2702, 'Admin.WebContent.Update', 'Edit Web Home Content', 'Admin', 'WebContent', 'Update', 'button', 2700, 2702, NULL, NULL, 1, SYSDATETIME());
END

SET IDENTITY_INSERT dbo.Permission OFF;

SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey IN ('Admin.WebContent', 'Admin.WebContent.List', 'Admin.WebContent.Update')
ORDER BY PermissionId;
