SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DECLARE @ParentPermissionId INT;
DECLARE @NextSortOrder INT;

SELECT @ParentPermissionId = PermissionId
FROM dbo.Permission
WHERE PermissionKey = 'Customer.Sale';

IF @ParentPermissionId IS NULL
BEGIN
    RAISERROR('Parent permission Customer.Sale not found.',16,1);
    RETURN;
END

SELECT @NextSortOrder = ISNULL(MAX(SortOrder), 0) + 1
FROM dbo.Permission
WHERE PermissionKey LIKE 'Customer.Sale.%';

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Permission
    WHERE PermissionKey = 'Customer.Sale.CreditMemoNoParentOverride'
)
BEGIN
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
        'Customer.Sale.CreditMemoNoParentOverride',
        'Approve Credit Memo Without Parent',
        'Customer',
        'Sale',
        'CreditMemoNoParentOverride',
        'action',
        @ParentPermissionId,
        @NextSortOrder,
        'Allow manager approval for standalone credit memo posting.',
        '',
        1
    );
END
