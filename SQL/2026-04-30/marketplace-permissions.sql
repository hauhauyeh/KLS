-- Marketplace Permissions
-- 50-ID gap between resources for future expansion

SET IDENTITY_INSERT Permission ON;

-- Menu level (8000)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8000, 'Marketplace', 'Marketplace', 'Marketplace', '', '', 'menu', NULL, 8000, 1, GETUTCDATE());

-- Resource: Account (8050)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8050, 'Marketplace.Account', 'Account', 'Marketplace', 'Account', '', 'resource', 8000, 8050, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8051, 'Marketplace.Account.List', 'View Accounts', 'Marketplace', 'Account', 'List', 'page', 8050, 8051, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8052, 'Marketplace.Account.Save', 'Create or Edit Account', 'Marketplace', 'Account', 'Save', 'button', 8050, 8052, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8053, 'Marketplace.Account.Delete', 'Delete Account', 'Marketplace', 'Account', 'Delete', 'button', 8050, 8053, 1, GETUTCDATE());

-- Resource: ItemMap (8100)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8100, 'Marketplace.ItemMap', 'Item Mapping', 'Marketplace', 'ItemMap', '', 'resource', 8000, 8100, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8101, 'Marketplace.ItemMap.List', 'View Item Mappings', 'Marketplace', 'ItemMap', 'List', 'page', 8100, 8101, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8102, 'Marketplace.ItemMap.Save', 'Create or Edit Mapping', 'Marketplace', 'ItemMap', 'Save', 'button', 8100, 8102, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8103, 'Marketplace.ItemMap.Delete', 'Delete Mapping', 'Marketplace', 'ItemMap', 'Delete', 'button', 8100, 8103, 1, GETUTCDATE());

-- Resource: Catalog (8150)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8150, 'Marketplace.Catalog', 'Catalog Search', 'Marketplace', 'Catalog', '', 'resource', 8000, 8150, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8151, 'Marketplace.Catalog.Search', 'Search Catalog', 'Marketplace', 'Catalog', 'Search', 'page', 8150, 8151, 1, GETUTCDATE());

-- Resource: Listing (8200)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8200, 'Marketplace.Listing', 'Listing Management', 'Marketplace', 'Listing', '', 'resource', 8000, 8200, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8201, 'Marketplace.Listing.List', 'View Listings', 'Marketplace', 'Listing', 'List', 'page', 8200, 8201, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8202, 'Marketplace.Listing.Push', 'Push Listing', 'Marketplace', 'Listing', 'Push', 'button', 8200, 8202, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8203, 'Marketplace.Listing.Delete', 'Delete Listing', 'Marketplace', 'Listing', 'Delete', 'button', 8200, 8203, 1, GETUTCDATE());

-- Resource: Pricing (8250)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8250, 'Marketplace.Pricing', 'Pricing', 'Marketplace', 'Pricing', '', 'resource', 8000, 8250, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8251, 'Marketplace.Pricing.Push', 'Push Price', 'Marketplace', 'Pricing', 'Push', 'button', 8250, 8251, 1, GETUTCDATE());

-- Resource: Inventory (8300)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8300, 'Marketplace.Inventory', 'Inventory', 'Marketplace', 'Inventory', '', 'resource', 8000, 8300, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8301, 'Marketplace.Inventory.Push', 'Push Inventory', 'Marketplace', 'Inventory', 'Push', 'button', 8300, 8301, 1, GETUTCDATE());

-- Resource: SyncLog (8350)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8350, 'Marketplace.SyncLog', 'Sync Logs', 'Marketplace', 'SyncLog', '', 'resource', 8000, 8350, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8351, 'Marketplace.SyncLog.List', 'View Sync Logs', 'Marketplace', 'SyncLog', 'List', 'page', 8350, 8351, 1, GETUTCDATE());

-- Resource: Order (8400)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8400, 'Marketplace.Order', 'Orders', 'Marketplace', 'Order', '', 'resource', 8000, 8400, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8401, 'Marketplace.Order.List', 'View Orders', 'Marketplace', 'Order', 'List', 'page', 8400, 8401, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8402, 'Marketplace.Order.Pull', 'Pull Orders', 'Marketplace', 'Order', 'Pull', 'button', 8400, 8402, 1, GETUTCDATE());
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive, CreatedAt)
VALUES (8403, 'Marketplace.Order.Convert', 'Convert to ERP Sales', 'Marketplace', 'Order', 'Convert', 'button', 8400, 8403, 1, GETUTCDATE());

SET IDENTITY_INSERT Permission OFF;
