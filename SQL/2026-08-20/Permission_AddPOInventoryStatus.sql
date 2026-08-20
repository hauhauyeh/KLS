-- Permission and CHINA role grants for the GUS PO Inventory Status report.
-- Idempotent by PermissionKey. Slot 6256 follows current Inventory report children
-- 6251-6255 in GUS_2026 as of 2026-08-20.

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @PermissionId INT = 6256;
DECLARE @PermissionKey NVARCHAR(150) = N'Report.Inventory.POInventoryStatus';
DECLARE @ChinaRoleName NVARCHAR(50) = N'CHINA';
DECLARE @ChinaRoleId INT;

SELECT @ChinaRoleId = SystemRoleId
FROM dbo.SystemRole
WHERE RoleName = @ChinaRoleName;

IF @ChinaRoleId IS NULL
BEGIN
    THROW 51000, 'Missing SystemRole CHINA.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = N'Report.Inventory')
BEGIN
    THROW 51000, 'Missing parent permission Report.Inventory.', 1;
END;

IF EXISTS (
    SELECT 1
    FROM dbo.Permission
    WHERE PermissionId = @PermissionId
      AND PermissionKey <> @PermissionKey
)
BEGIN
    THROW 51000, 'PermissionId 6256 is already used by another permission.', 1;
END;

IF EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = @PermissionKey)
BEGIN
    UPDATE dbo.Permission
    SET DisplayName = N'PO Inventory Status',
        [Module] = N'Report',
        [Resource] = N'Inventory',
        [Action] = N'POInventoryStatus',
        PermissionType = N'page',
        ParentPermissionId = 6250,
        SortOrder = 6256,
        IsActive = 1
    WHERE PermissionKey = @PermissionKey;
END
ELSE
BEGIN
    SET IDENTITY_INSERT dbo.Permission ON;

    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (@PermissionId, @PermissionKey, N'PO Inventory Status', N'Report', N'Inventory', N'POInventoryStatus', N'page', 6250, 6256, NULL, NULL, 1, SYSDATETIME());

    SET IDENTITY_INSERT dbo.Permission OFF;
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.RolePermission
    WHERE SystemRoleId = @ChinaRoleId
      AND PermissionId = @PermissionId
)
BEGIN
    INSERT INTO dbo.RolePermission (SystemRoleId, PermissionId, GrantedAt, GrantedBy)
    VALUES (@ChinaRoleId, @PermissionId, SYSDATETIME(), NULL);
END;

-- PO Inventory Status is now authorized by its own permission; remove the
-- normal inventory report permissions from CHINA so the normal menu stays hidden.
DELETE rp
FROM dbo.RolePermission rp
JOIN dbo.Permission p ON p.PermissionId = rp.PermissionId
WHERE rp.SystemRoleId = @ChinaRoleId
  AND p.PermissionKey IN (
      N'Report.Inventory.InventoryStatus',
      N'Report.Inventory.InventoryIncoming'
  );

-- Basic Item remains a normal report and should stay available to CHINA.
INSERT INTO dbo.RolePermission (SystemRoleId, PermissionId, GrantedAt, GrantedBy)
SELECT @ChinaRoleId, p.PermissionId, SYSDATETIME(), NULL
FROM dbo.Permission p
WHERE p.PermissionKey = N'Report.Item.BasicItem'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.RolePermission rp
      WHERE rp.SystemRoleId = @ChinaRoleId
        AND rp.PermissionId = p.PermissionId
  );

COMMIT;

SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder, IsActive
FROM dbo.Permission
WHERE PermissionKey IN (
    N'Report.Inventory.POInventoryStatus',
    N'Report.Inventory.InventoryStatus',
    N'Report.Inventory.InventoryIncoming',
    N'Report.Item.BasicItem'
)
ORDER BY SortOrder, PermissionId;

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
