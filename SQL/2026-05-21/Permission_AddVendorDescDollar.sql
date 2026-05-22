/*
    Permission_AddVendorDescDollar.sql
    2026-05-21

    Adds a new page under the existing Report.Vendor resource bucket:

        6503  Report.Vendor.DescDollar  page, parent = 6500

    Slot 6503 is the next free under the Report.Vendor bucket
    (6500=resource, 6501=PurchaseHistory, 6502=Statement, 6503=DescDollar).

    Idempotent. Does NOT touch RolePermission — grant separately if needed.

    Companion change: KLS\SQL\2026-04-30\Permission_Reseed.sql should
    eventually be updated to include this row so a future full re-seed stays
    in sync.
*/

SET NOCOUNT ON;
SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6503)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6503, 'Report.Vendor.DescDollar', 'Descending Dollar', 'Report', 'Vendor', 'DescDollar', 'page', 6500, 6503, NULL);
END;

SET IDENTITY_INSERT dbo.Permission OFF;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey LIKE 'Report.Vendor%'
ORDER BY SortOrder;
