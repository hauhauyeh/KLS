/*
    Permission_AddCustomerSalesSummary.sql
    2026-05-13

    Adds one new row to the Permission table so the Customer Sales Summary
    report can be configured in the "Permission Setup For Role" UI.

    Idempotent — safe to re-run. Only inserts the row if its PermissionId
    is not already present. Does NOT touch RolePermission (no role
    assignments are altered by this patch).

    The Report.Sales resource (PermissionId 6400) already exists; we add
    only the new page row under it. Next free slot in the Report.Sales
    family is 6415 (verified against the existing rows 6401..6414).

        6415  Report.Sales.CustomerSalesSummary    page, parent = 6400

    After this script runs:
        * The new "Customer Sales Summary" entry appears under the Sales
          Report group in the role-permission UI.
        * Admins can grant the page permission to specific roles.
        * The controller's [PermissionKey("Report.Sales.CustomerSalesSummary")]
          check will succeed for any role granted this permission.

    Permission evaluation is exact-match on RolePermission rows
    (PermissionService.cs:27-31), so roles that already see other
    Report.Sales pages will NOT see this report until explicitly granted
    via the role-permission UI.

    Companion change: KLS\SQL\2026-04-30\Permission_Reseed.sql is updated
    to include the same row so a future full re-seed stays in sync.
*/

SET NOCOUNT ON;
SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 6415)
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (6415, 'Report.Sales.CustomerSalesSummary', 'Customer Sales Summary', 'Report', 'Sales', 'CustomerSalesSummary', 'page', 6400, 6415, NULL);
END;

SET IDENTITY_INSERT dbo.Permission OFF;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId
FROM dbo.Permission
WHERE PermissionKey = 'Report.Sales.CustomerSalesSummary';
