/*
    Permission_AddItemReports.sql
    2026-05-19

    Adds the new Report.Item resource bucket and one page under it:

        6550  Report.Item                          resource, parent = 6000 (Report menu)
        6551  Report.Item.ItemCustomerAnalysis     page,     parent = 6550

    Slot 6550 is the next 50-aligned slot after Report.Vendor (6500) in
    the existing reserve-50-per-resource scheme:
        6400  Report.Sales
        6450  Report.Timesheet
        6500  Report.Vendor
        6550  Report.Item      <-- new

    Idempotent. Does NOT touch RolePermission.

    Companion change: KLS\SQL\2026-04-30\Permission_Reseed.sql should
    eventually be updated to include these rows so a future full re-seed
    stays in sync.
*/

SET NOCOUNT ON;
SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6550)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6550, 'Report.Item', 'Item Report', 'Report', 'Item', '', 'resource', 6000, 6550, NULL);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6551)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6551, 'Report.Item.ItemCustomerAnalysis', 'Item Customer Analysis', 'Report', 'Item', 'ItemCustomerAnalysis', 'page', 6550, 6551, NULL);
END;

SET IDENTITY_INSERT dbo.Permission OFF;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey LIKE 'Report.Item%'
ORDER BY SortOrder;
