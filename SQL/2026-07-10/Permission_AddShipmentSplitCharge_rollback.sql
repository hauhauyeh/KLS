-- Rollback for Permission_AddShipmentSplitCharge.sql - removes the button child only.
-- (Leaves the Vendor.Shipment resource 7250 intact - shared by the other shipment actions.)

DELETE FROM dbo.Permission WHERE PermissionKey = 'Vendor.Shipment.SplitCharge';
