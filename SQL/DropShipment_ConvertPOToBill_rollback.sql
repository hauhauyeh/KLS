-- DropShipment_ConvertPOToBill_rollback.sql
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'DropShipment_ConvertPOToBill')
    DROP PROCEDURE dbo.DropShipment_ConvertPOToBill;
