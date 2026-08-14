-- Permission seed for Sales Quote role setup.
-- Idempotent by PermissionKey. Does NOT touch RolePermission; grant access through the admin role UI.
-- Slots 3400-3408 are near Customer.Sale (3350-3380) and verified free in GUS_2026 on 2026-08-13.
-- Deploy with sqlcmd -b -i.

IF EXISTS (
    SELECT 1
    FROM dbo.Permission
    WHERE PermissionId BETWEEN 3400 AND 3408
      AND PermissionKey NOT LIKE 'Customer.SalesQuote%'
)
    THROW 51080, 'PermissionId range 3400-3408 is already used by another permission.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Customer')
    THROW 51081, 'Customer menu permission is missing.', 1;

DECLARE @Rows TABLE
(
    PermissionId INT NOT NULL,
    PermissionKey NVARCHAR(150) NOT NULL,
    DisplayName NVARCHAR(200) NOT NULL,
    Module NVARCHAR(50) NOT NULL,
    Resource NVARCHAR(50) NOT NULL,
    [Action] NVARCHAR(50) NOT NULL,
    PermissionType NVARCHAR(20) NOT NULL,
    ParentPermissionId INT NULL,
    SortOrder INT NOT NULL,
    OldKey NVARCHAR(150) NULL
);

INSERT INTO @Rows
    (PermissionId, PermissionKey, DisplayName, Module, Resource, [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
VALUES
    (3400, 'Customer.SalesQuote', 'Sales Quote', 'Customer', 'SalesQuote', '', 'resource', 3000, 3400, NULL),
    (3401, 'Customer.SalesQuote.List', 'View Sales Quotes', 'Customer', 'SalesQuote', 'List', 'page', 3400, 3401, NULL),
    (3402, 'Customer.SalesQuote.Create', 'Create Sales Quote', 'Customer', 'SalesQuote', 'Create', 'button', 3400, 3402, NULL),
    (3403, 'Customer.SalesQuote.Update', 'Edit Sales Quote', 'Customer', 'SalesQuote', 'Update', 'button', 3400, 3403, NULL),
    (3404, 'Customer.SalesQuote.Delete', 'Delete Sales Quote', 'Customer', 'SalesQuote', 'Delete', 'button', 3400, 3404, NULL),
    (3405, 'Customer.SalesQuote.UpdateStatus', 'Edit Quote Status', 'Customer', 'SalesQuote', 'UpdateStatus', 'button', 3400, 3405, NULL),
    (3406, 'Customer.SalesQuote.ConvertToSales', 'Convert Sales Quote', 'Customer', 'SalesQuote', 'ConvertToSales', 'button', 3400, 3406, NULL),
    (3407, 'Customer.SalesQuote.SeePdf', 'View PDF Document', 'Customer', 'SalesQuote', 'SeePdf', 'button', 3400, 3407, NULL),
    (3408, 'Customer.SalesQuote.EmailPdf', 'Email PDF Document', 'Customer', 'SalesQuote', 'EmailPdf', 'button', 3400, 3408, NULL);

SET IDENTITY_INSERT dbo.Permission ON;

INSERT INTO dbo.Permission
    (PermissionId, PermissionKey, DisplayName, Module, Resource, [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
SELECT
    r.PermissionId,
    r.PermissionKey,
    r.DisplayName,
    r.Module,
    r.Resource,
    r.[Action],
    r.PermissionType,
    r.ParentPermissionId,
    r.SortOrder,
    NULL,
    r.OldKey,
    1,
    SYSDATETIME()
FROM @Rows r
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.Permission p
    WHERE p.PermissionKey = r.PermissionKey
);

SET IDENTITY_INSERT dbo.Permission OFF;

SELECT PermissionId, PermissionKey, DisplayName, Module, Resource, [Action], PermissionType, ParentPermissionId, SortOrder, IsActive
FROM dbo.Permission
WHERE PermissionKey LIKE 'Customer.SalesQuote%'
ORDER BY PermissionId;
