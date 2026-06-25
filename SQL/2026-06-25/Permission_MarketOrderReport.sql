/*
    Permission_MarketOrderReport.sql
    2026-06-25

    Adds two rows to the Permission table for the Market Order Report:

        6650  Report.Marketplace        resource, parent = 6000
        6651  Report.Marketplace.OrderReport  page,     parent = 6650

    Idempotent. Does NOT touch RolePermission.

    After this script runs:
        * "Marketplace" appears as a report group in the role-permission UI.
        * "Order Report" appears under it.
        * The controller's [PermissionKey("Report.Marketplace.OrderReport")]
          check will succeed for any role granted this permission.
*/

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6650)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6650, 'Report.Marketplace', 'Marketplace', 'Report', 'Marketplace', NULL, 'resource', 6000, 6650, NULL);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6651)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6651, 'Report.Marketplace.OrderReport', 'Order Report', 'Report', 'Marketplace', 'OrderReport', 'page', 6650, 6651, NULL);
END;

SET IDENTITY_INSERT dbo.Permission OFF;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey LIKE 'Report.Marketplace%';
