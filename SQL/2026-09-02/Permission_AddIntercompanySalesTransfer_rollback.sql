-- Rollback for intercompany sales transfer permission catalog rows.
-- Removes only rows added by Permission_AddIntercompanySalesTransfer.sql.

SET XACT_ABORT ON;
BEGIN TRAN;

DELETE rp
FROM dbo.RolePermission rp
INNER JOIN dbo.Permission p ON p.PermissionId = rp.PermissionId
WHERE p.PermissionKey IN
(
    N'Intercompany.SalesTransfer.Create',
    N'Intercompany.SalesTransfer.View',
    N'Intercompany.SalesTransfer',
    N'Intercompany'
);

DELETE FROM dbo.Permission
WHERE PermissionKey IN
(
    N'Intercompany.SalesTransfer.Create',
    N'Intercompany.SalesTransfer.View',
    N'Intercompany.SalesTransfer',
    N'Intercompany'
);

COMMIT;

SELECT PermissionId, PermissionKey
FROM dbo.Permission
WHERE PermissionKey LIKE N'Intercompany%';
