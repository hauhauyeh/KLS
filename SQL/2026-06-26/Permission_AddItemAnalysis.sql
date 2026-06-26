-- Permission_AddItemAnalysis.sql
-- Seeds the Report.Item.ItemAnalysis page permission (id 6503) under the Report.Item
-- resource (6500), next free slot after ItemCustomerAnalysis (6501) / ItemVendorAnalysis (6502).
-- Idempotent. Does NOT touch RolePermission -- role grants are assigned separately (admin UI),
-- so after this runs you must grant the permission to the roles that should see the report.
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM Permission WHERE PermissionKey = 'Report.Item.ItemAnalysis')
BEGIN
    SET IDENTITY_INSERT Permission ON;
    INSERT INTO Permission
        (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (6503, 'Report.Item.ItemAnalysis', 'Item -> Item Analysis', 'Report', 'Item', 'ItemAnalysis', 'page', 6500, 6503, NULL, NULL, 1, GETDATE());
    SET IDENTITY_INSERT Permission OFF;
    PRINT 'Inserted Report.Item.ItemAnalysis (6503).';
END
ELSE
    PRINT 'Report.Item.ItemAnalysis already exists -- skipped.';
