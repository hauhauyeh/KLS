/*
Rollback for MVAP_A_SCHEMA_2026-07-14.
Drops the additive multi-vendor charge AP schema. Run only before B/C/D readers exist
or after those readers are reverted.
*/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.ShipmentChargeBillLine', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.ShipmentChargeBillLine;
END;

IF OBJECT_ID('dbo.ShipmentChargeBill', 'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.ShipmentChargeBill;
END;

IF COL_LENGTH('dbo.ShipmentCharge', 'IsGeneratedFromChargeBills') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ShipmentCharge
    DROP CONSTRAINT IF EXISTS DF_ShipmentCharge_IsGeneratedFromChargeBills;

    ALTER TABLE dbo.ShipmentCharge
    DROP COLUMN IsGeneratedFromChargeBills;
END;

SELECT 'MVAP_A_SCHEMA_2026-07-14_ROLLBACK' AS Marker;
