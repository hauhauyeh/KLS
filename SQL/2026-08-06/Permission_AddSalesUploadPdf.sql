-- Permission seed for the Order Manager "Upload PDF" action.
-- The Customer.Sale resource (3350) already exists; this adds one button child.
-- Idempotent. Slot 3380 is the next free child under 3350 (3379 = UntrackedReturns; 3380 verified free 2026-08-06).
-- Deploy with sqlcmd -b -i.

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = 'Customer.Sale.UploadPdf')
BEGIN
    SET IDENTITY_INSERT dbo.Permission ON;

    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, Module, Resource, Action, PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (3380, 'Customer.Sale.UploadPdf', 'Upload PDF Document', 'Customer', 'Sale', 'UploadPdf', 'button', 3350, 3380, NULL, 'Sales-UploadPdf', 1, SYSDATETIME());

    SET IDENTITY_INSERT dbo.Permission OFF;
END

SELECT PermissionId, PermissionKey, DisplayName, ParentPermissionId, SortOrder, IsActive
FROM dbo.Permission
WHERE PermissionKey = 'Customer.Sale.UploadPdf';
