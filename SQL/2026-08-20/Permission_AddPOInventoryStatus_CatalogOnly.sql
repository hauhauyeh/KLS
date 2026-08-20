-- Catalog-only permission seed for PO Inventory Status.
-- Use for clients that should know the permission key but should not grant it
-- to any role. Idempotent by PermissionKey.

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @PermissionId INT = 6256;
DECLARE @PermissionKey NVARCHAR(150) = N'Report.Inventory.POInventoryStatus';

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = N'Report.Inventory')
BEGIN
    THROW 51000, 'Missing parent permission Report.Inventory.', 1;
END;

IF EXISTS (
    SELECT 1
    FROM dbo.Permission
    WHERE PermissionId = @PermissionId
      AND PermissionKey <> @PermissionKey
)
BEGIN
    THROW 51000, 'PermissionId 6256 is already used by another permission.', 1;
END;

IF EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = @PermissionKey)
BEGIN
    UPDATE dbo.Permission
    SET DisplayName = N'PO Inventory Status',
        [Module] = N'Report',
        [Resource] = N'Inventory',
        [Action] = N'POInventoryStatus',
        PermissionType = N'page',
        ParentPermissionId = 6250,
        SortOrder = 6256,
        IsActive = 1
    WHERE PermissionKey = @PermissionKey;
END
ELSE
BEGIN
    SET IDENTITY_INSERT dbo.Permission ON;

    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (@PermissionId, @PermissionKey, N'PO Inventory Status', N'Report', N'Inventory', N'POInventoryStatus', N'page', 6250, 6256, NULL, NULL, 1, SYSDATETIME());

    SET IDENTITY_INSERT dbo.Permission OFF;
END;

COMMIT;

SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder, IsActive
FROM dbo.Permission
WHERE PermissionKey = @PermissionKey;

SELECT sr.RoleName, p.PermissionKey
FROM dbo.SystemRole sr
JOIN dbo.RolePermission rp ON rp.SystemRoleId = sr.SystemRoleId
JOIN dbo.Permission p ON p.PermissionId = rp.PermissionId
WHERE p.PermissionKey = @PermissionKey
ORDER BY sr.RoleName;
