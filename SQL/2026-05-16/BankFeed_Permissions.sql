SET QUOTED_IDENTIFIER ON
GO

-- Bank Feed Permissions
-- Parent: Accounting (PermissionId 1000)

IF NOT EXISTS (SELECT 1 FROM Permission WHERE PermissionId = 1400)
    INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive)
    VALUES (1400, 'Accounting.BankFeed', 'Bank Feed', 'Accounting', 'BankFeed', '', 'resource', 1000, 1400, 1);

IF NOT EXISTS (SELECT 1 FROM Permission WHERE PermissionId = 1401)
    INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive)
    VALUES (1401, 'Accounting.BankFeed.List', 'View Bank Feed', 'Accounting', 'BankFeed', 'List', 'page', 1400, 1401, 1);

IF NOT EXISTS (SELECT 1 FROM Permission WHERE PermissionId = 1402)
    INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive)
    VALUES (1402, 'Accounting.BankFeed.Import', 'Import Bank Feed', 'Accounting', 'BankFeed', 'Import', 'button', 1400, 1402, 1);

IF NOT EXISTS (SELECT 1 FROM Permission WHERE PermissionId = 1403)
    INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive)
    VALUES (1403, 'Accounting.BankFeed.Match', 'Match Bank Feed', 'Accounting', 'BankFeed', 'Match', 'button', 1400, 1403, 1);

IF NOT EXISTS (SELECT 1 FROM Permission WHERE PermissionId = 1404)
    INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive)
    VALUES (1404, 'Accounting.BankFeed.Exclude', 'Exclude Bank Feed', 'Accounting', 'BankFeed', 'Exclude', 'button', 1400, 1404, 1);

IF NOT EXISTS (SELECT 1 FROM Permission WHERE PermissionId = 1405)
    INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive)
    VALUES (1405, 'Accounting.BankFeed.Setup', 'Bank Feed Setup', 'Accounting', 'BankFeed', 'Setup', 'button', 1400, 1405, 1);

IF NOT EXISTS (SELECT 1 FROM Permission WHERE PermissionId = 1406)
    INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, IsActive)
    VALUES (1406, 'Accounting.BankFeed.Delete', 'Delete Bank Feed', 'Accounting', 'BankFeed', 'Delete', 'button', 1400, 1406, 1);
GO
