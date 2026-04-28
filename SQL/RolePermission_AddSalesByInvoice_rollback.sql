SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DECLARE @SalesByInvoicePermissionId INT;

SELECT @SalesByInvoicePermissionId = PermissionId
FROM dbo.Permission
WHERE PermissionKey = 'Report.Sales.SalesByInvoice';

IF @SalesByInvoicePermissionId IS NULL
BEGIN
    RETURN;
END

DELETE FROM dbo.RolePermission
WHERE SystemRoleId IN (3)
  AND PermissionId = @SalesByInvoicePermissionId;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.RolePermission
    WHERE PermissionId = @SalesByInvoicePermissionId
)
BEGIN
    DELETE FROM dbo.Permission
    WHERE PermissionId = @SalesByInvoicePermissionId
      AND PermissionKey = 'Report.Sales.SalesByInvoice';
END
GO
