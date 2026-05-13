SET QUOTED_IDENTIFIER ON;

INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, Module, Resource, [Action], PermissionType, ParentPermissionId, SortOrder, Description, OldKey, IsActive, CreatedAt)
VALUES
(7312, 'Vendor.VendorPayment.PrintCheck', 'Print Check', 'Vendor', 'VendorPayment', 'PrintCheck', 'button', 7300, 7312, NULL, NULL, 1, GETDATE());
