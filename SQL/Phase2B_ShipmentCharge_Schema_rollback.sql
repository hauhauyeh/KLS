-- Phase 2B rollback: Remove UpdatedAt from ShipmentCharge
ALTER TABLE dbo.ShipmentCharge DROP COLUMN UpdatedAt;
