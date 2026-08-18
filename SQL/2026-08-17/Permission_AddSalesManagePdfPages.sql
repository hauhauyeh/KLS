-- Permission seed for the Order Manager "Manage PDF Pages" action.
-- The Customer.Sale resource (3350) already exists; this adds one button child.
-- Idempotent. Slot 3381 follows UploadPdf (3380).
-- Deploy with sqlcmd -b -i.

IF EXISTS (
    SELECT 1
    FROM dbo.Permission
    WHERE PermissionId = 3381
      AND PermissionKey <> 'Customer.Sale.ManagePdfPages'
)
BEGIN
    THROW 50001, 'PermissionId 3381 is already used by another permission.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Customer.Sale.ManagePdfPages')
BEGIN
    SET IDENTITY_INSERT dbo.Permission ON;

    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (3381, 'Customer.Sale.ManagePdfPages', 'Manage PDF Pages', 'Customer', 'Sale', 'ManagePdfPages', 'button', 3350, 3381, NULL, 'Sales-ManagePdfPages', 1, SYSDATETIME());

    SET IDENTITY_INSERT dbo.Permission OFF;
END;

SELECT PermissionId, PermissionKey, DisplayName, ParentPermissionId, SortOrder, IsActive
FROM dbo.Permission
WHERE PermissionKey = 'Customer.Sale.ManagePdfPages';
