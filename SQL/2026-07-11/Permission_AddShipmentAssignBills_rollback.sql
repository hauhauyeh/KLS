-- Rollback for Permission_AddShipmentAssignBills.sql - remove the Assign Bills permission (slot 7259).
DELETE FROM dbo.Permission WHERE PermissionId = 7259 AND PermissionKey = 'Vendor.Shipment.AssignBills';
