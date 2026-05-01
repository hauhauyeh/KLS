-- Rollback: restore original Shipment_UnAllocation
DROP PROCEDURE IF EXISTS dbo.Shipment_UnAllocation;

IF OBJECT_ID('dbo.Shipment_UnAllocation_prev') IS NOT NULL
    EXEC sp_rename 'Shipment_UnAllocation_prev', 'Shipment_UnAllocation';
