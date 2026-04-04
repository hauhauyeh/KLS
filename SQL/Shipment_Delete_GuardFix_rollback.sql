-- Rollback: restore original Shipment_Delete
DROP PROCEDURE IF EXISTS dbo.Shipment_Delete;

IF OBJECT_ID('dbo.Shipment_Delete_prev') IS NOT NULL
    EXEC sp_rename 'Shipment_Delete_prev', 'Shipment_Delete';
