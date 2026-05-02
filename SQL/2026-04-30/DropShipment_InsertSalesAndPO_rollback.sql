-- DropShipment_InsertSalesAndPO_rollback.sql
IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'DropShipment_InsertSalesAndPO')
    DROP PROCEDURE dbo.DropShipment_InsertSalesAndPO;
