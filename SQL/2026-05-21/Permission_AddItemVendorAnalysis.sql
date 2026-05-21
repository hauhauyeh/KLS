/*
    Permission_AddItemVendorAnalysis.sql
    2026-05-21

    Adds a new page under the existing Report.Item resource bucket:

        6552  Report.Item.ItemVendorAnalysis  page, parent = 6550

    Slot 6552 is the next free under the Report.Item bucket
    (6550=resource, 6551=ItemCustomerAnalysis, 6552=ItemVendorAnalysis).

    Idempotent. Does NOT touch RolePermission — grant separately if needed.

    Prereq: Permission_AddItemReports.sql (2026-05-19) must have run so the
    parent resource 6550 exists. (If 6550 is missing the INSERT will fail
    on the ParentPermissionId FK.)

    Companion change: KLS\SQL\2026-04-30\Permission_Reseed.sql should
    eventually be updated to include this row so a future full re-seed stays
    in sync.
*/

SET NOCOUNT ON;
SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6552)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6552, 'Report.Item.ItemVendorAnalysis', 'Item Vendor Analysis', 'Report', 'Item', 'ItemVendorAnalysis', 'page', 6550, 6552, NULL);
END;

SET IDENTITY_INSERT dbo.Permission OFF;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey LIKE 'Report.Item%'
ORDER BY SortOrder;
