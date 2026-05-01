SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DECLARE @ParentPermissionId INT;
DECLARE @SalesByInvoicePermissionId INT;
DECLARE @NextSortOrder INT;

SELECT @ParentPermissionId = PermissionId
FROM dbo.Permission
WHERE PermissionKey = 'Report.Sales';

IF @ParentPermissionId IS NULL
BEGIN
    RAISERROR('Parent permission Report.Sales not found.', 16, 1);
    RETURN;
END

SELECT @SalesByInvoicePermissionId = PermissionId
FROM dbo.Permission
WHERE PermissionKey = 'Report.Sales.SalesByInvoice';

IF @SalesByInvoicePermissionId IS NULL
BEGIN
    SELECT @NextSortOrder = ISNULL(MAX(SortOrder), @ParentPermissionId) + 1
    FROM dbo.Permission
    WHERE PermissionKey LIKE 'Report.Sales.%';

    INSERT INTO dbo.Permission
    (
        PermissionKey,
        DisplayName,
        Module,
        Resource,
        Action,
        PermissionType,
        ParentPermissionId,
        SortOrder,
        Description,
        OldKey,
        IsActive
    )
    VALUES
    (
        'Report.Sales.SalesByInvoice',
        'Sales By Invoice',
        'Report',
        'Sales',
        'SalesByInvoice',
        'page',
        @ParentPermissionId,
        @NextSortOrder,
        'Sales by invoice report.',
        'Reports-SalesByInvoice',
        1
    );

    SET @SalesByInvoicePermissionId = SCOPE_IDENTITY();
END

INSERT INTO dbo.RolePermission (SystemRoleId, PermissionId)
SELECT v.SystemRoleId, @SalesByInvoicePermissionId
FROM (VALUES
    (3)    -- Sales
) AS v(SystemRoleId)
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.RolePermission rp
    WHERE rp.SystemRoleId = v.SystemRoleId
      AND rp.PermissionId = @SalesByInvoicePermissionId
);
GO
