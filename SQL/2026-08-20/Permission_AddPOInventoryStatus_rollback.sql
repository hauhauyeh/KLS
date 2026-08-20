-- Rollback for Permission_AddPOInventoryStatus.sql.
-- Restores CHINA's previous normal inventory report grants and removes the
-- PO-specific report permission/grant.

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @ChinaRoleName NVARCHAR(50) = N'CHINA';
DECLARE @ChinaRoleId INT;

SELECT @ChinaRoleId = SystemRoleId
FROM dbo.SystemRole
WHERE RoleName = @ChinaRoleName;

IF @ChinaRoleId IS NULL
BEGIN
    THROW 51000, 'Missing SystemRole CHINA.', 1;
END;

INSERT INTO dbo.RolePermission (SystemRoleId, PermissionId, GrantedAt, GrantedBy)
SELECT @ChinaRoleId, p.PermissionId, SYSDATETIME(), NULL
FROM dbo.Permission p
WHERE p.PermissionKey IN (
      N'Report.Inventory.InventoryStatus',
      N'Report.Inventory.InventoryIncoming',
      N'Report.Item.BasicItem'
  )
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.RolePermission rp
      WHERE rp.SystemRoleId = @ChinaRoleId
        AND rp.PermissionId = p.PermissionId
  );

DELETE rp
FROM dbo.RolePermission rp
JOIN dbo.Permission p ON p.PermissionId = rp.PermissionId
WHERE rp.SystemRoleId = @ChinaRoleId
  AND p.PermissionKey = N'Report.Inventory.POInventoryStatus';

DELETE FROM dbo.Permission
WHERE PermissionKey = N'Report.Inventory.POInventoryStatus';

COMMIT;

SELECT sr.RoleName, p.PermissionKey
FROM dbo.SystemRole sr
JOIN dbo.RolePermission rp ON rp.SystemRoleId = sr.SystemRoleId
JOIN dbo.Permission p ON p.PermissionId = rp.PermissionId
WHERE sr.RoleName = @ChinaRoleName
  AND (
      p.PermissionKey LIKE N'Report.Inventory.%'
      OR p.PermissionKey = N'Report.Item.BasicItem'
  )
ORDER BY p.PermissionKey;
