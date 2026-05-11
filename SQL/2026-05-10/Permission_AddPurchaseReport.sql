/*
    Permission_AddPurchaseReport.sql
    2026-05-10

    Adds two new rows to the Permission table so the Vendor Purchase Summary
    report can be configured in the "Permission Setup For Role" UI.

    Idempotent — safe to re-run. Only inserts rows whose PermissionId is not
    already present. Does NOT touch RolePermission (no role assignments are
    altered by this patch).

    Row layout follows the existing Report.* pattern (PermissionIds 6000-6452).
    Next free 50-gap slot is 6500.

        6500  Report.Purchase                          resource, parent = 6000 (Report menu)
        6501  Report.Purchase.VendorPurchaseSummary    page,     parent = 6500

    After this script runs:
        * The new Purchase report sub-tree appears in the role-permission UI.
        * Admins can grant the page permission to specific roles.
        * The controller's [PermissionKey("Report.Purchase.VendorPurchaseSummary")]
          check will succeed for any role granted this permission.

    Companion change: KLS\SQL\2026-04-30\Permission_Reseed.sql is updated to
    include the same two rows so a future full re-seed stays in sync.
*/

SET NOCOUNT ON;
SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6500)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6500, 'Report.Purchase', 'Purchase Report', 'Report', 'Purchase', '', 'resource', 6000, 6500, NULL);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6501)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6501, 'Report.Purchase.VendorPurchaseSummary', 'Vendor Purchase Summary', 'Report', 'Purchase', 'VendorPurchaseSummary', 'page', 6500, 6501, NULL);
END;

SET IDENTITY_INSERT dbo.Permission OFF;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey IN ('Report.Purchase', 'Report.Purchase.VendorPurchaseSummary')
ORDER BY PermissionId;
