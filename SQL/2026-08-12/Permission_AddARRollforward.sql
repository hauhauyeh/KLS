/*
    Permission_AddARRollforward.sql
    2026-08-12

    Adds a new page under the existing Report.AR resource bucket:

        6104  Report.AR.ARRollforward  page, parent = 6100

    Existing AR report slots:
        6100  Report.AR
        6101  Report.AR.ARInvoice
        6102  Report.AR.ARMonth
        6103  Report.AR.Aging

    Idempotent. Does NOT touch RolePermission; grant separately if needed.
*/

SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Report.AR.ARRollforward')
BEGIN
    SET IDENTITY_INSERT dbo.Permission ON;

    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (6104, 'Report.AR.ARRollforward', 'AR Rollforward', 'Report', 'AR', 'ARRollforward', 'page', 6100, 6104, NULL, NULL, 1, SYSDATETIME());

    SET IDENTITY_INSERT dbo.Permission OFF;
END;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder
FROM dbo.Permission
WHERE PermissionKey LIKE 'Report.AR%'
ORDER BY SortOrder;
