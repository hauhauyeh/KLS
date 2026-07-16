/*
MVAP_A_SCHEMA_2026-07-14
Plan A only: additive source tables for multi-vendor shipment charge AP bills
plus a generated-row flag on ShipmentCharge. No behavior changes.
*/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.ShipmentChargeBill', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ShipmentChargeBill
    (
        ShipmentChargeBillId INT IDENTITY(1,1) NOT NULL,
        ShipmentId INT NOT NULL,
        VendorPayeeId INT NOT NULL,
        VendorDocNumber NVARCHAR(100) NULL,
        BillDate DATE NULL,
        PurchaseId INT NULL,
        Notes NVARCHAR(500) NULL,
        CreatedAt DATETIME NOT NULL
            CONSTRAINT DF_ShipmentChargeBill_CreatedAt DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME NULL,

        CONSTRAINT PK_ShipmentChargeBill
            PRIMARY KEY (ShipmentChargeBillId),

        CONSTRAINT FK_ShipmentChargeBill_Shipment
            FOREIGN KEY (ShipmentId) REFERENCES dbo.Shipment(ShipmentId),

        CONSTRAINT FK_ShipmentChargeBill_VendorPayee
            FOREIGN KEY (VendorPayeeId) REFERENCES dbo.Payee(PayeeId),

        CONSTRAINT FK_ShipmentChargeBill_Purchase
            FOREIGN KEY (PurchaseId) REFERENCES dbo.Purchase(PurchaseId)
    );

END
ELSE
BEGIN
    PRINT 'ShipmentChargeBill already exists; skipping table creation.';
END;

IF OBJECT_ID('dbo.ShipmentChargeBill', 'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.ShipmentChargeBill') AND name = 'IX_ShipmentChargeBill_ShipmentId')
BEGIN
    CREATE INDEX IX_ShipmentChargeBill_ShipmentId
        ON dbo.ShipmentChargeBill (ShipmentId);
END;

IF OBJECT_ID('dbo.ShipmentChargeBill', 'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.ShipmentChargeBill') AND name = 'IX_ShipmentChargeBill_PurchaseId')
BEGIN
    CREATE INDEX IX_ShipmentChargeBill_PurchaseId
        ON dbo.ShipmentChargeBill (PurchaseId)
        WHERE PurchaseId IS NOT NULL;
END;

IF OBJECT_ID('dbo.ShipmentChargeBillLine', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ShipmentChargeBillLine
    (
        ShipmentChargeBillLineId INT IDENTITY(1,1) NOT NULL,
        ShipmentChargeBillId INT NOT NULL,
        ChargeType VARCHAR(50) NOT NULL,
        ChargeAmount DECIMAL(18,2) NOT NULL,
        Notes NVARCHAR(500) NULL,
        CreatedAt DATETIME NOT NULL
            CONSTRAINT DF_ShipmentChargeBillLine_CreatedAt DEFAULT GETUTCDATE(),
        UpdatedAt DATETIME NULL,

        CONSTRAINT PK_ShipmentChargeBillLine
            PRIMARY KEY (ShipmentChargeBillLineId),

        CONSTRAINT FK_ShipmentChargeBillLine_Bill
            FOREIGN KEY (ShipmentChargeBillId)
            REFERENCES dbo.ShipmentChargeBill(ShipmentChargeBillId),

        CONSTRAINT CK_ShipmentChargeBillLine_ChargeType
            CHECK (ChargeType IN ('Freight','CustomDuty','Tariff','Tax','Brokerage','PortCharges','Insurance','ImportCommission','Other')),

        CONSTRAINT CK_ShipmentChargeBillLine_Amount
            CHECK (ChargeAmount >= 0)
    );

END
ELSE
BEGIN
    PRINT 'ShipmentChargeBillLine already exists; skipping table creation.';
END;

IF OBJECT_ID('dbo.ShipmentChargeBillLine', 'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.ShipmentChargeBillLine') AND name = 'IX_ShipmentChargeBillLine_BillId')
BEGIN
    CREATE INDEX IX_ShipmentChargeBillLine_BillId
        ON dbo.ShipmentChargeBillLine (ShipmentChargeBillId);
END;

IF COL_LENGTH('dbo.ShipmentCharge', 'IsGeneratedFromChargeBills') IS NULL
BEGIN
    ALTER TABLE dbo.ShipmentCharge
    ADD IsGeneratedFromChargeBills BIT NOT NULL
        CONSTRAINT DF_ShipmentCharge_IsGeneratedFromChargeBills DEFAULT (0);
END
ELSE
BEGIN
    PRINT 'ShipmentCharge.IsGeneratedFromChargeBills already exists; skipping column add.';
END;

SELECT 'MVAP_A_SCHEMA_2026-07-14' AS Marker;
