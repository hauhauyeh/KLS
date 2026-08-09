SET XACT_ABORT ON;
GO

-- 2026-08-09
-- Split Purchase Order create and edit permission.
-- Idempotent. Adds Vendor.PurchaseOrder.Update and grants it to roles that
-- currently have Vendor.PurchaseOrder.Create so existing roles keep today's
-- create/edit behavior until an admin removes Edit PO.

BEGIN TRAN;

DECLARE @ParentPermissionId INT;
DECLARE @CreatePermissionId INT;
DECLARE @UpdatePermissionId INT;
DECLARE @UpdatePermissionKey NVARCHAR(200) = N'Vendor.PurchaseOrder.Update';

SELECT @ParentPermissionId = PermissionId
FROM dbo.Permission
WHERE PermissionKey = N'Vendor.PurchaseOrder';

SELECT @CreatePermissionId = PermissionId
FROM dbo.Permission
WHERE PermissionKey = N'Vendor.PurchaseOrder.Create';

IF @ParentPermissionId IS NULL
    THROW 50001, 'Missing Vendor.PurchaseOrder parent permission.', 1;

IF @CreatePermissionId IS NULL
    THROW 50002, 'Missing Vendor.PurchaseOrder.Create permission.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.Permission
    WHERE PermissionId = 7210
      AND PermissionKey <> @UpdatePermissionKey
)
    THROW 50003, 'PermissionId 7210 is already used by another permission.', 1;

UPDATE dbo.Permission
SET DisplayName = N'Create PO',
    [Action] = N'Create',
    PermissionType = N'button',
    ParentPermissionId = @ParentPermissionId,
    IsActive = 1
WHERE PermissionKey = N'Vendor.PurchaseOrder.Create';

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = @UpdatePermissionKey)
BEGIN
    SET IDENTITY_INSERT dbo.Permission ON;

    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, Module, Resource, [Action],
         PermissionType, ParentPermissionId, SortOrder, OldKey, IsActive)
    VALUES
        (7210, @UpdatePermissionKey, N'Edit PO',
         N'Vendor', N'PurchaseOrder', N'Update',
         N'button', @ParentPermissionId, 7210, N'PurchaseOrders-Checkout', 1);

    SET IDENTITY_INSERT dbo.Permission OFF;
END
ELSE
BEGIN
    UPDATE dbo.Permission
    SET DisplayName = N'Edit PO',
        Module = N'Vendor',
        Resource = N'PurchaseOrder',
        [Action] = N'Update',
        PermissionType = N'button',
        ParentPermissionId = @ParentPermissionId,
        SortOrder = 7210,
        OldKey = N'PurchaseOrders-Checkout',
        IsActive = 1
    WHERE PermissionKey = @UpdatePermissionKey;
END

SELECT @UpdatePermissionId = PermissionId
FROM dbo.Permission
WHERE PermissionKey = @UpdatePermissionKey;

INSERT INTO dbo.RolePermission (SystemRoleId, PermissionId, GrantedBy)
SELECT rp.SystemRoleId, @UpdatePermissionId, rp.GrantedBy
FROM dbo.RolePermission rp
WHERE rp.PermissionId = @CreatePermissionId
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.RolePermission existing
      WHERE existing.SystemRoleId = rp.SystemRoleId
        AND existing.PermissionId = @UpdatePermissionId
  );

COMMIT;
GO

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder, OldKey, IsActive
FROM dbo.Permission
WHERE PermissionKey IN (N'Vendor.PurchaseOrder.Create', N'Vendor.PurchaseOrder.Update')
ORDER BY PermissionId;

SELECT p.PermissionKey, COUNT(*) AS RoleGrantCount
FROM dbo.RolePermission rp
JOIN dbo.Permission p ON p.PermissionId = rp.PermissionId
WHERE p.PermissionKey IN (N'Vendor.PurchaseOrder.Create', N'Vendor.PurchaseOrder.Update')
GROUP BY p.PermissionKey
ORDER BY p.PermissionKey;
