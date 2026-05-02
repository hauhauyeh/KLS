-- ============================================================
-- Drop Shipment — Permission Seed
-- Follows Vendor numbering: 7000 (menu), 7050-7300 (resources)
-- Next resource slot: 7350
-- ============================================================

SET IDENTITY_INSERT Permission ON;

-- Drop Shipment (5 rows: 1 resource + 1 page + 3 buttons)
INSERT INTO Permission (PermissionId, PermissionKey, DisplayName, [Module], [Resource], [Action], PermissionType, ParentPermissionId, SortOrder, OldKey)
VALUES
(7350, 'Vendor.DropShipment',                'Drop Shipment',          'Vendor', 'DropShipment', '',              'resource', 7000, 7350, NULL),
(7351, 'Vendor.DropShipment.Manage',         'Drop Shipment',          'Vendor', 'DropShipment', 'Manage',        'page',     7350, 7351, NULL),
(7352, 'Vendor.DropShipment.Create',         'Create Drop Ship Order', 'Vendor', 'DropShipment', 'Create',        'button',   7351, 7352, NULL),
(7353, 'Vendor.DropShipment.UpdateShipQty',  'Update Ship Qty',        'Vendor', 'DropShipment', 'UpdateShipQty', 'button',   7351, 7353, NULL),
(7354, 'Vendor.DropShipment.ConvertToBill',  'Convert PO to Bill',     'Vendor', 'DropShipment', 'ConvertToBill', 'button',   7351, 7354, NULL);

SET IDENTITY_INSERT Permission OFF;

-- Verify
SELECT PermissionId, PermissionKey, DisplayName, PermissionType, ParentPermissionId, SortOrder
FROM Permission
WHERE [Resource] = 'DropShipment'
ORDER BY SortOrder;
