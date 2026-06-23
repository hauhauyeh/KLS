/*
    Permission_AddARAging.sql
    2026-06-09

    Adds a new page under the existing Report.AR resource bucket:

        6103  Report.AR.Aging  page, parent = 6100

    Slot 6103 is the next free under the Report.AR bucket
    (6100=resource, 6101=ARInvoice, 6102=ARMonth).

    Gates both Due Date and Invoice Date variants of the new AR Aging
    report — one route /report/araging with ?basis=due or ?basis=invoice.
    Single component, single permission.

    Idempotent. Does NOT touch RolePermission — grant separately if needed.

    Companion change: KLS\SQL\2026-04-30\Permission_Reseed.sql should
    eventually be updated to include this row so a future full re-seed
    stays in sync.
*/

SET NOCOUNT ON;
SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6103)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6103, 'Report.AR.Aging', 'AR Aging', 'Report', 'AR', 'Aging', 'page', 6100, 6103, NULL);
END;

SET IDENTITY_INSERT dbo.Permission OFF;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey LIKE 'Report.AR%'
ORDER BY SortOrder;
