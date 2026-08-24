SET XACT_ABORT ON;
GO

-- 2026-08-24
-- Add the missing grantable Role UI permission for Email PO.
-- Idempotent. Does not grant the permission to any role.

BEGIN TRAN;

DECLARE @ParentPermissionId INT;
DECLARE @PermissionId INT = 7211;
DECLARE @PermissionKey NVARCHAR(200) = N'Vendor.PurchaseOrder.EmailPdf';
DECLARE @SortOrder INT = 7205;

SELECT @ParentPermissionId = PermissionId
FROM dbo.Permission
WHERE PermissionKey = N'Vendor.PurchaseOrder'
  AND IsActive = 1;

IF @ParentPermissionId IS NULL
    THROW 50001, 'Missing active Vendor.PurchaseOrder parent permission.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.Permission
    WHERE PermissionId = @PermissionId
      AND PermissionKey <> @PermissionKey
)
    THROW 50002, 'PermissionId 7211 is already used by another permission.', 1;

-- Email PO should appear immediately after Print Purchase Order. Because
-- SortOrder is an int, shift later Purchase Order siblings once before
-- inserting or moving Email PO into the 7205 slot.
IF NOT EXISTS (
    SELECT 1
    FROM dbo.Permission
    WHERE PermissionKey = @PermissionKey
      AND ParentPermissionId = @ParentPermissionId
      AND SortOrder = @SortOrder
)
BEGIN
    UPDATE dbo.Permission
    SET SortOrder = SortOrder + 1
    WHERE ParentPermissionId = @ParentPermissionId
      AND PermissionKey <> @PermissionKey
      AND SortOrder >= @SortOrder;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = @PermissionKey)
BEGIN
    SET IDENTITY_INSERT dbo.Permission ON;

    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, Module, Resource, [Action],
         PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (@PermissionId, @PermissionKey, N'Email PO',
         N'Vendor', N'PurchaseOrder', N'EmailPdf',
         N'button', @ParentPermissionId, @SortOrder, NULL, N'PurchaseOrders-EmailPdf', 1, SYSDATETIME());

    SET IDENTITY_INSERT dbo.Permission OFF;
END
ELSE
BEGIN
    UPDATE dbo.Permission
    SET DisplayName = N'Email PO',
        Module = N'Vendor',
        Resource = N'PurchaseOrder',
        [Action] = N'EmailPdf',
        PermissionType = N'button',
        ParentPermissionId = @ParentPermissionId,
        SortOrder = @SortOrder,
        OldKey = N'PurchaseOrders-EmailPdf',
        IsActive = 1
    WHERE PermissionKey = @PermissionKey;
END;

COMMIT;
GO

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder, OldKey, IsActive
FROM dbo.Permission
WHERE PermissionKey = N'Vendor.PurchaseOrder.EmailPdf';

SELECT PermissionId, PermissionKey, DisplayName, SortOrder
FROM dbo.Permission
WHERE ParentPermissionId = (
    SELECT PermissionId
    FROM dbo.Permission
    WHERE PermissionKey = N'Vendor.PurchaseOrder'
)
ORDER BY SortOrder, PermissionId;
