-- ============================================================
-- Permission_ItemCost  (2026-08-27)
-- Two new buttons under Product.Item (resource 5050):
--   5059  Product.Item.ImportCost  Import Cost  (screen, template, preview, import, mapping)
--   5060  Product.Item.ApplyCost   Apply Cost   (Apply Now)
-- Ids verified free on 2026-08-27 (5051-5058 used; 5100 next resource).
-- Guarded: safe to re-run.
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

SET IDENTITY_INSERT dbo.Permission ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 5059)
    INSERT INTO dbo.Permission (Module, Resource, [Action], PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
    VALUES ('Product', 'Item', 'ImportCost', 5059, 'Product.Item.ImportCost', 'Import Cost', 'button', 5050, 5059, 1, GETDATE());

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionId = 5060)
    INSERT INTO dbo.Permission (Module, Resource, [Action], PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
    VALUES ('Product', 'Item', 'ApplyCost', 5060, 'Product.Item.ApplyCost', 'Apply Cost', 'button', 5050, 5060, 1, GETDATE());

SET IDENTITY_INSERT dbo.Permission OFF;
GO
