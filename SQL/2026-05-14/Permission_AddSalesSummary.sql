/*
    Permission_AddSalesSummary.sql
    2026-05-14

    Adds one new row to the Permission table so the Sales Summary
    report (period-over-period trend) can be configured in the
    "Permission Setup For Role" UI.

    Idempotent. Does NOT touch RolePermission.

    The Report.Sales resource (PermissionId 6400) already exists; this
    patch adds only the new page row under it. Next free slot in the
    Report.Sales family is 6416 (verified — max id in family is 6415,
    occupied by CustomerSalesSummary added 2026-05-13).

        6416  Report.Sales.SalesSummary    page, parent = 6400

    After this script runs:
        * The new "Sales Summary" entry appears under Sales Report in
          the role-permission UI.
        * Admins can grant the page permission to specific roles.
        * The controller's [PermissionKey("Report.Sales.SalesSummary")]
          check will succeed for any role granted this permission.

    Companion change: KLS\SQL\2026-04-30\Permission_Reseed.sql is updated
    to include the same row so a future full re-seed stays in sync.
*/

SET NOCOUNT ON;
SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6416)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6416, 'Report.Sales.SalesSummary', 'Sales Summary', 'Report', 'Sales', 'SalesSummary', 'page', 6400, 6416, NULL);
END;

SET IDENTITY_INSERT dbo.Permission OFF;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey = 'Report.Sales.SalesSummary';
