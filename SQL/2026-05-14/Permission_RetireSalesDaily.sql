/*
    Permission_RetireSalesDaily.sql
    2026-05-14

    Soft-retires the Sales Daily and Sales Daily 2 reports.

        6401  Report.Sales.SalesDaily
        6408  Report.Sales.SalesDaily2

    Two DB changes:
        1. Revoke any existing RolePermission grants for these two
           PermissionIds. Roles that had granted access lose it.
        2. Mark the Permission rows IsActive = 0. The role-permission
           UI filters by IsActive (PermissionService.cs:29 + :44), so
           admins will no longer see these as options to grant going
           forward.

    Idempotent. Safe to re-run.

    Companion change: KLS\SQL\2026-04-30\Permission_Reseed.sql has both
    rows commented out (with a 2026-05-14 retire marker) so a future
    full re-seed will not re-create them. The PermissionIds 6401 and
    6408 are kept reserved -- future net-new reports should use 6417+
    (next free slot after 6416 SalesSummary).

    Application-side companions (already in code, not in this script):
        - menu-navigation.component.html: nav entries commented out
          with a 2026-05-14 retire marker.
        - Routes (/report/salesdaily, /report/salesdaily2) and the
          component code remain in place so the reports can be
          resurrected by uncommenting + flipping IsActive = 1 +
          re-granting permission.

    Rollback (if resurrecting):
        UPDATE dbo.Permission SET IsActive = 1 WHERE PermissionId IN (6401, 6408);
        Re-grant via the role-permission UI per role.
        Uncomment the nav entries in menu-navigation.component.html.
        Uncomment the Permission_Reseed.sql lines.
*/

SET NOCOUNT ON;

-- 1. Revoke grants.
DELETE FROM dbo.RolePermission
WHERE PermissionId IN (6401, 6408);

PRINT CONCAT('RolePermission rows revoked: ', CAST(@@ROWCOUNT AS NVARCHAR(10)));

-- 2. Hide from role-permission UI.
UPDATE dbo.Permission
SET IsActive = 0
WHERE PermissionId IN (6401, 6408)
  AND IsActive = 1;

PRINT CONCAT('Permission rows marked IsActive=0: ', CAST(@@ROWCOUNT AS NVARCHAR(10)));

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, IsActive
FROM dbo.Permission
WHERE PermissionId IN (6401, 6408);
