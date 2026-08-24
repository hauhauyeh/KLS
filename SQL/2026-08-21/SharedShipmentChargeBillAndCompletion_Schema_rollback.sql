SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- WARNING: This rollback deletes all data stored in the shared shipment charge bill tables.

-- Remove completion audit dependencies before dropping Shipment columns.
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Shipment_ChargesCompletedBy_Employee')
BEGIN
    ALTER TABLE dbo.Shipment
        DROP CONSTRAINT FK_Shipment_ChargesCompletedBy_Employee;
END
GO

IF COL_LENGTH(N'dbo.Shipment', N'ChargesCompletedBy') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Shipment
        DROP COLUMN ChargesCompletedBy;
END
GO

IF COL_LENGTH(N'dbo.Shipment', N'ChargesCompletedAt') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Shipment
        DROP COLUMN ChargesCompletedAt;
END
GO

IF EXISTS
(
    SELECT 1
    FROM sys.default_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.Shipment')
      AND name = N'DF_Shipment_AreChargesComplete'
)
BEGIN
    ALTER TABLE dbo.Shipment
        DROP CONSTRAINT DF_Shipment_AreChargesComplete;
END
GO

IF COL_LENGTH(N'dbo.Shipment', N'AreChargesComplete') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Shipment
        DROP COLUMN AreChargesComplete;
END
GO

-- Remove the existing-table source link before dropping its shared split target.
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ShipmentChargeBill_SharedSplit')
BEGIN
    ALTER TABLE dbo.ShipmentChargeBill
        DROP CONSTRAINT FK_ShipmentChargeBill_SharedSplit;
END
GO

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.ShipmentChargeBill')
      AND name = N'UX_ShipmentChargeBill_SourceSharedShipmentChargeBillSplitId'
)
BEGIN
    DROP INDEX UX_ShipmentChargeBill_SourceSharedShipmentChargeBillSplitId
        ON dbo.ShipmentChargeBill;
END
GO

IF COL_LENGTH(N'dbo.ShipmentChargeBill', N'SourceSharedShipmentChargeBillSplitId') IS NOT NULL
BEGIN
    ALTER TABLE dbo.ShipmentChargeBill
        DROP COLUMN SourceSharedShipmentChargeBillSplitId;
END
GO

-- Remove split indexes and constraints before dropping the split table.
IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.SharedShipmentChargeBillSplit')
      AND name = N'IX_SharedShipmentChargeBillSplit_GeneratedVendorDocNumber'
)
BEGIN
    DROP INDEX IX_SharedShipmentChargeBillSplit_GeneratedVendorDocNumber
        ON dbo.SharedShipmentChargeBillSplit;
END
GO

IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.SharedShipmentChargeBillSplit')
      AND name = N'UX_SharedShipmentChargeBillSplit_Bill_Shipment'
)
BEGIN
    DROP INDEX UX_SharedShipmentChargeBillSplit_Bill_Shipment
        ON dbo.SharedShipmentChargeBillSplit;
END
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SharedShipmentChargeBillSplit_Percent')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillSplit
        DROP CONSTRAINT CK_SharedShipmentChargeBillSplit_Percent;
END
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SharedShipmentChargeBillSplit_Amount')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillSplit
        DROP CONSTRAINT CK_SharedShipmentChargeBillSplit_Amount;
END
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SharedShipmentChargeBillSplit_Method')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillSplit
        DROP CONSTRAINT CK_SharedShipmentChargeBillSplit_Method;
END
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SharedShipmentChargeBillSplit_Shipment')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillSplit
        DROP CONSTRAINT FK_SharedShipmentChargeBillSplit_Shipment;
END
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SharedShipmentChargeBillSplit_Bill')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillSplit
        DROP CONSTRAINT FK_SharedShipmentChargeBillSplit_Bill;
END
GO

-- Remove line constraints before dropping the line table.
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SharedShipmentChargeBillLine_Amount')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillLine
        DROP CONSTRAINT CK_SharedShipmentChargeBillLine_Amount;
END
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SharedShipmentChargeBillLine_ChargeType')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillLine
        DROP CONSTRAINT CK_SharedShipmentChargeBillLine_ChargeType;
END
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SharedShipmentChargeBillLine_Bill')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillLine
        DROP CONSTRAINT FK_SharedShipmentChargeBillLine_Bill;
END
GO

-- Remove header constraints after all child references are gone.
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SharedShipmentChargeBill_Status')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBill
        DROP CONSTRAINT CK_SharedShipmentChargeBill_Status;
END
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SharedShipmentChargeBill_VendorPayee')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBill
        DROP CONSTRAINT FK_SharedShipmentChargeBill_VendorPayee;
END
GO

-- Drop child tables before the shared header.
IF OBJECT_ID(N'dbo.SharedShipmentChargeBillSplit', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.SharedShipmentChargeBillSplit;
END
GO

IF OBJECT_ID(N'dbo.SharedShipmentChargeBillLine', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.SharedShipmentChargeBillLine;
END
GO

IF OBJECT_ID(N'dbo.SharedShipmentChargeBill', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.SharedShipmentChargeBill;
END
GO
