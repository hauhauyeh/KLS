/*
    Permission_AddItemCategoryImageManage.sql
    2026-08-29

    Adds one category image management button permission under Product.ItemCategory:

        5156  Product.ItemCategory.ImageManage  button, parent = 5150

    Idempotent. Does NOT touch RolePermission; grant separately in role setup.

    Companion change: KLS\SQL\2026-04-30\Permission_Reseed.sql is updated to
    include this row so a future full re-seed stays in sync.
*/

SET NOCOUNT ON;

IF EXISTS (
    SELECT 1
    FROM dbo.Permission
    WHERE PermissionId = 5156
      AND PermissionKey <> 'Product.ItemCategory.ImageManage'
)
BEGIN
    THROW 51560, 'PermissionId 5156 is already used by another permission.', 1;
END;

SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Product.ItemCategory.ImageManage')
BEGIN
    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
    VALUES
        (5156, 'Product.ItemCategory.ImageManage', 'Manage Product Category Images', 'Product', 'ItemCategory', 'ImageManage', 'button', 5150, 5156, NULL);
END;

SET IDENTITY_INSERT dbo.Permission OFF;

SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder, IsActive
FROM dbo.Permission
WHERE PermissionKey = 'Product.ItemCategory.ImageManage';
