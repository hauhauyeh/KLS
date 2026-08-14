-- Permission seed for the Basic Item report.
-- Idempotent by PermissionKey. Slot 6505 is the next Item report child after
-- 6501-6504 in GUS_2026 as of 2026-08-14.

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @PermissionId INT = 6505;
DECLARE @PermissionKey NVARCHAR(150) = N'Report.Item.BasicItem';

IF NOT EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = N'Report.Item')
BEGIN
    THROW 51000, 'Missing parent permission Report.Item.', 1;
END;

IF EXISTS (
    SELECT 1
    FROM dbo.Permission
    WHERE PermissionId = @PermissionId
      AND PermissionKey <> @PermissionKey
)
BEGIN
    THROW 51000, 'PermissionId 6505 is already used by another permission.', 1;
END;

IF EXISTS (SELECT 1 FROM dbo.Permission WHERE PermissionKey = @PermissionKey)
BEGIN
    UPDATE dbo.Permission
    SET DisplayName = N'Item -> Basic Item',
        [Module] = N'Report',
        [Resource] = N'Item',
        [Action] = N'BasicItem',
        PermissionType = N'page',
        ParentPermissionId = 6500,
        SortOrder = 6505,
        IsActive = 1
    WHERE PermissionKey = @PermissionKey;
END
ELSE
BEGIN
    SET IDENTITY_INSERT dbo.Permission ON;

    INSERT INTO dbo.Permission
        (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
    VALUES
        (6505, @PermissionKey, N'Item -> Basic Item', N'Report', N'Item', N'BasicItem', N'page', 6500, 6505, NULL, NULL, 1, SYSDATETIME());

    SET IDENTITY_INSERT dbo.Permission OFF;
END;

COMMIT;

SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder, IsActive
FROM dbo.Permission
WHERE PermissionKey = @PermissionKey;
