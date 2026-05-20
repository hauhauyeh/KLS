/*
    Permission_AddVendorReports.sql
    2026-05-19

    Adds the new Report.Vendor resource bucket and one page under it:

        6500  Report.Vendor                  resource, parent = 6000 (Report menu)
        6501  Report.Vendor.PurchaseHistory  page,     parent = 6500

    Slot 6500 is the next 50-aligned slot after Report.Timesheet (6450) in
    the existing reserve-50-per-resource scheme:
        6000  Report
        6050  Report.AP
        6100  Report.AR
        6150  Report.Banking
        6200  Report.Customer
        6250  Report.Inventory
        6300  Report.Payroll
        6350  Report.PL
        6400  Report.Sales
        6450  Report.Timesheet
        6500  Report.Vendor      <-- new

    Idempotent. Does NOT touch RolePermission.

    Companion change: KLS\SQL\2026-04-30\Permission_Reseed.sql should
    eventually be updated to include these rows so a future full re-seed
    stays in sync.
*/

SET NOCOUNT ON;
SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6500)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6500, 'Report.Vendor', 'Vendor Report', 'Report', 'Vendor', '', 'resource', 6000, 6500, NULL);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6501)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6501, 'Report.Vendor.PurchaseHistory', 'Purchase History', 'Report', 'Vendor', 'PurchaseHistory', 'page', 6500, 6501, NULL);
END;

SET IDENTITY_INSERT dbo.Permission OFF;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey LIKE 'Report.Vendor%'
ORDER BY SortOrder;
