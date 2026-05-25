/*
    Permission_AddAPAging.sql
    2026-05-25

    Adds a new page under the existing Report.AP resource bucket:

        6054  Report.AP.Aging  page, parent = 6050

    Slot 6054 is the next free under the Report.AP bucket
    (6050=resource, 6051=APCheck, 6052=CheckToBePrinted, 6053=APInvoice).

    Gates BOTH new menu entries (one route /report/apaging with ?basis=due
    or ?basis=invoice). Single component, single permission.

    Idempotent. Does NOT touch RolePermission — grant separately if needed.

    Companion change: KLS\SQL\2026-04-30\Permission_Reseed.sql should
    eventually be updated to include this row so a future full re-seed stays
    in sync.
*/

SET NOCOUNT ON;
SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6054)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6054, 'Report.AP.Aging', 'AP Aging', 'Report', 'AP', 'Aging', 'page', 6050, 6054, NULL);
END;

SET IDENTITY_INSERT dbo.Permission OFF;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey LIKE 'Report.AP%'
ORDER BY SortOrder;
