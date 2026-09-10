/*
    Permission_AddInventoryAudit.sql
    2026-09-10

    Adds the Inventory Audit report page permission under the existing
    Report.Inventory resource bucket.

    Idempotent. Does NOT touch RolePermission.

    Companion change: KLS\SQL\2026-04-30\Permission_Reseed.sql is updated
    so a future full re-seed stays in sync. Do not deploy the reseed file
    to existing databases for this feature.
*/

SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Report.Inventory.InventoryAudit')
BEGIN
    SET IDENTITY_INSERT dbo.Permission ON;

    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6257, 'Report.Inventory.InventoryAudit', 'Inventory Audit', 'Report', 'Inventory', 'InventoryAudit', 'page', 6250, 6257, 'Reports-InventoryAudit');

    SET IDENTITY_INSERT dbo.Permission OFF;
END;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder, OldKey
FROM dbo.Permission
WHERE PermissionKey LIKE 'Report.Inventory%'
ORDER BY SortOrder;
