-- DropShipment_UpdateShipQty_rollback.sql
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'DropShipment_UpdateShipQty')
    DROP PROCEDURE dbo.DropShipment_UpdateShipQty;
