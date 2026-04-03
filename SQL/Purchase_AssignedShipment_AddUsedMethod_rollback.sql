-- Rollback: restore original Purchase_AssignedShipment
DROP PROCEDURE IF EXISTS dbo.Purchase_AssignedShipment;

IF OBJECT_ID('dbo.Purchase_AssignedShipment_prev') IS NOT NULL
    EXEC sp_rename 'Purchase_AssignedShipment_prev', 'Purchase_AssignedShipment';
