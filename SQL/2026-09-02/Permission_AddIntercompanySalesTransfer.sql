-- Permission seed for intercompany sales transfer.
-- Idempotent. Does NOT touch RolePermission; grant access separately through the admin role UI.
-- Deploy: run via sqlcmd -i after approval.

SET XACT_ABORT ON;
BEGIN TRAN;

DECLARE @Rows TABLE
(
    PermissionId int NOT NULL,
    PermissionKey nvarchar(150) NOT NULL,
    DisplayName nvarchar(200) NOT NULL,
    [Module] nvarchar(50) NOT NULL,
    [Resource] nvarchar(50) NOT NULL,
    [Action] nvarchar(50) NOT NULL,
    PermissionType nvarchar(20) NOT NULL,
    ParentPermissionId int NULL,
    SortOrder int NOT NULL
);

INSERT INTO @Rows
    (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder)
VALUES
    (9200, N'Intercompany', N'Intercompany', N'Intercompany', N'', N'', N'menu', NULL, 9200),
    (9210, N'Intercompany.SalesTransfer', N'Sales Transfer', N'Intercompany', N'SalesTransfer', N'', N'resource', 9200, 9210),
    (9211, N'Intercompany.SalesTransfer.View', N'View Sales Transfer', N'Intercompany', N'SalesTransfer', N'View', N'page', 9210, 9211),
    (9212, N'Intercompany.SalesTransfer.Create', N'Create Sales Transfer', N'Intercompany', N'SalesTransfer', N'Create', N'button', 9210, 9212);

IF EXISTS
(
    SELECT 1
    FROM dbo.Permission p
    INNER JOIN @Rows r ON r.PermissionId = p.PermissionId
    WHERE p.PermissionKey <> r.PermissionKey
)
BEGIN
    THROW 51000, 'One or more intercompany permission ids are already used by different permission keys.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.Permission p
    INNER JOIN @Rows r ON r.PermissionKey = p.PermissionKey
    WHERE p.PermissionId <> r.PermissionId
)
BEGIN
    THROW 51000, 'One or more intercompany permission keys already exist with different permission ids.', 1;
END;

SET IDENTITY_INSERT dbo.Permission ON;

INSERT INTO dbo.Permission
    (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
SELECT
    r.PermissionId,
    r.PermissionKey,
    r.DisplayName,
    r.[Module],
    r.[Resource],
    r.[Action],
    r.PermissionType,
    r.ParentPermissionId,
    r.SortOrder,
    NULL,
    NULL,
    1,
    SYSDATETIME()
FROM @Rows r
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.Permission p
    WHERE p.PermissionKey = r.PermissionKey
);

SET IDENTITY_INSERT dbo.Permission OFF;

UPDATE p
SET
    DisplayName = r.DisplayName,
    [Module] = r.[Module],
    [Resource] = r.[Resource],
    [Action] = r.[Action],
    PermissionType = r.PermissionType,
    ParentPermissionId = r.ParentPermissionId,
    SortOrder = r.SortOrder,
    IsActive = 1
FROM dbo.Permission p
INNER JOIN @Rows r ON r.PermissionKey = p.PermissionKey;

COMMIT;

SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder, IsActive
FROM dbo.Permission
WHERE PermissionKey IN
(
    N'Intercompany',
    N'Intercompany.SalesTransfer',
    N'Intercompany.SalesTransfer.View',
    N'Intercompany.SalesTransfer.Create'
)
ORDER BY PermissionId;
