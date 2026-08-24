SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Add the upstream source header for one real vendor charge bill.
IF OBJECT_ID(N'dbo.SharedShipmentChargeBill', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SharedShipmentChargeBill
    (
        SharedShipmentChargeBillId int IDENTITY(1,1) NOT NULL,
        VendorPayeeId int NOT NULL,
        VendorDocNumber nvarchar(100) NULL,
        BillDate date NULL,
        Status nvarchar(20) NOT NULL
            CONSTRAINT DF_SharedShipmentChargeBill_Status DEFAULT (N'Draft'),
        Notes nvarchar(500) NULL,
        CreatedAt datetime NOT NULL
            CONSTRAINT DF_SharedShipmentChargeBill_CreatedAt DEFAULT (GETUTCDATE()),
        UpdatedAt datetime NULL,
        CONSTRAINT PK_SharedShipmentChargeBill
            PRIMARY KEY CLUSTERED (SharedShipmentChargeBillId)
    );
END
GO

-- Preserve the original charge type and amount. V1 service logic permits one line per shared bill.
IF OBJECT_ID(N'dbo.SharedShipmentChargeBillLine', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SharedShipmentChargeBillLine
    (
        SharedShipmentChargeBillLineId int IDENTITY(1,1) NOT NULL,
        SharedShipmentChargeBillId int NOT NULL,
        ChargeType nvarchar(50) NOT NULL,
        ChargeAmount decimal(18,2) NOT NULL,
        Notes nvarchar(500) NULL,
        CreatedAt datetime NOT NULL
            CONSTRAINT DF_SharedShipmentChargeBillLine_CreatedAt DEFAULT (GETUTCDATE()),
        UpdatedAt datetime NULL,
        CONSTRAINT PK_SharedShipmentChargeBillLine
            PRIMARY KEY CLUSTERED (SharedShipmentChargeBillLineId)
    );
END
GO

-- Store one target shipment allocation and its user-confirmed generated vendor document number.
IF OBJECT_ID(N'dbo.SharedShipmentChargeBillSplit', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SharedShipmentChargeBillSplit
    (
        SharedShipmentChargeBillSplitId int IDENTITY(1,1) NOT NULL,
        SharedShipmentChargeBillId int NOT NULL,
        ShipmentId int NOT NULL,
        SplitMethod nvarchar(30) NOT NULL,
        SplitPercent decimal(9,6) NULL,
        SplitAmount decimal(18,2) NOT NULL,
        GeneratedVendorDocNumber nvarchar(100) NULL,
        Notes nvarchar(500) NULL,
        CreatedAt datetime NOT NULL
            CONSTRAINT DF_SharedShipmentChargeBillSplit_CreatedAt DEFAULT (GETUTCDATE()),
        UpdatedAt datetime NULL,
        CONSTRAINT PK_SharedShipmentChargeBillSplit
            PRIMARY KEY CLUSTERED (SharedShipmentChargeBillSplitId)
    );
END
GO

-- Add the shared-source link without changing existing charge bill rows.
IF COL_LENGTH(N'dbo.ShipmentChargeBill', N'SourceSharedShipmentChargeBillSplitId') IS NULL
BEGIN
    ALTER TABLE dbo.ShipmentChargeBill
        ADD SourceSharedShipmentChargeBillSplitId int NULL;
END
GO

-- Grandfather legacy shipments as complete. New shipments default to incomplete.
IF COL_LENGTH(N'dbo.Shipment', N'AreChargesComplete') IS NULL
BEGIN
    ALTER TABLE dbo.Shipment
        ADD AreChargesComplete bit NULL;
END
GO

IF EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.Shipment')
      AND name = N'AreChargesComplete'
      AND is_nullable = 1
)
BEGIN
    UPDATE dbo.Shipment
    SET AreChargesComplete = 1
    WHERE AreChargesComplete IS NULL;

    ALTER TABLE dbo.Shipment
        ALTER COLUMN AreChargesComplete bit NOT NULL;
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.default_constraints dc
    INNER JOIN sys.columns c
        ON c.object_id = dc.parent_object_id
       AND c.column_id = dc.parent_column_id
    WHERE dc.parent_object_id = OBJECT_ID(N'dbo.Shipment')
      AND c.name = N'AreChargesComplete'
)
BEGIN
    ALTER TABLE dbo.Shipment
        ADD CONSTRAINT DF_Shipment_AreChargesComplete
            DEFAULT ((0)) FOR AreChargesComplete;
END
GO

IF COL_LENGTH(N'dbo.Shipment', N'ChargesCompletedAt') IS NULL
BEGIN
    ALTER TABLE dbo.Shipment
        ADD ChargesCompletedAt datetime NULL;
END
GO

IF COL_LENGTH(N'dbo.Shipment', N'ChargesCompletedBy') IS NULL
BEGIN
    ALTER TABLE dbo.Shipment
        ADD ChargesCompletedBy int NULL;
END
GO

-- Add shared bill constraints separately so a rerun can finish a partially applied script.
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SharedShipmentChargeBill_VendorPayee')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBill WITH CHECK
        ADD CONSTRAINT FK_SharedShipmentChargeBill_VendorPayee
            FOREIGN KEY (VendorPayeeId) REFERENCES dbo.Payee (PayeeId);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SharedShipmentChargeBill_Status')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBill WITH CHECK
        ADD CONSTRAINT CK_SharedShipmentChargeBill_Status
            CHECK (Status IN (N'Draft', N'Applied', N'Void'));
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SharedShipmentChargeBillLine_Bill')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillLine WITH CHECK
        ADD CONSTRAINT FK_SharedShipmentChargeBillLine_Bill
            FOREIGN KEY (SharedShipmentChargeBillId)
            REFERENCES dbo.SharedShipmentChargeBill (SharedShipmentChargeBillId);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SharedShipmentChargeBillLine_ChargeType')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillLine WITH CHECK
        ADD CONSTRAINT CK_SharedShipmentChargeBillLine_ChargeType
            CHECK (ChargeType IN
            (
                N'Freight', N'CustomDuty', N'Tariff', N'Tax', N'Brokerage',
                N'PortCharges', N'Insurance', N'ImportCommission', N'Other'
            ));
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SharedShipmentChargeBillLine_Amount')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillLine WITH CHECK
        ADD CONSTRAINT CK_SharedShipmentChargeBillLine_Amount
            CHECK (ChargeAmount >= 0);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SharedShipmentChargeBillSplit_Bill')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillSplit WITH CHECK
        ADD CONSTRAINT FK_SharedShipmentChargeBillSplit_Bill
            FOREIGN KEY (SharedShipmentChargeBillId)
            REFERENCES dbo.SharedShipmentChargeBill (SharedShipmentChargeBillId);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SharedShipmentChargeBillSplit_Shipment')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillSplit WITH CHECK
        ADD CONSTRAINT FK_SharedShipmentChargeBillSplit_Shipment
            FOREIGN KEY (ShipmentId) REFERENCES dbo.Shipment (ShipmentId);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SharedShipmentChargeBillSplit_Method')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillSplit WITH CHECK
        ADD CONSTRAINT CK_SharedShipmentChargeBillSplit_Method
            CHECK (SplitMethod IN (N'Equal', N'Percentage', N'ManualAmount'));
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SharedShipmentChargeBillSplit_Amount')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillSplit WITH CHECK
        ADD CONSTRAINT CK_SharedShipmentChargeBillSplit_Amount
            CHECK (SplitAmount >= 0);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SharedShipmentChargeBillSplit_Percent')
BEGIN
    ALTER TABLE dbo.SharedShipmentChargeBillSplit WITH CHECK
        ADD CONSTRAINT CK_SharedShipmentChargeBillSplit_Percent
            CHECK (SplitPercent IS NULL OR (SplitPercent >= 0 AND SplitPercent <= 100));
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.SharedShipmentChargeBillSplit')
      AND name = N'UX_SharedShipmentChargeBillSplit_Bill_Shipment'
)
BEGIN
    CREATE UNIQUE INDEX UX_SharedShipmentChargeBillSplit_Bill_Shipment
        ON dbo.SharedShipmentChargeBillSplit (SharedShipmentChargeBillId, ShipmentId);
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.SharedShipmentChargeBillSplit')
      AND name = N'IX_SharedShipmentChargeBillSplit_GeneratedVendorDocNumber'
)
BEGIN
    CREATE INDEX IX_SharedShipmentChargeBillSplit_GeneratedVendorDocNumber
        ON dbo.SharedShipmentChargeBillSplit (GeneratedVendorDocNumber);
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.ShipmentChargeBill')
      AND name = N'UX_ShipmentChargeBill_SourceSharedShipmentChargeBillSplitId'
)
BEGIN
    CREATE UNIQUE INDEX UX_ShipmentChargeBill_SourceSharedShipmentChargeBillSplitId
        ON dbo.ShipmentChargeBill (SourceSharedShipmentChargeBillSplitId)
        WHERE SourceSharedShipmentChargeBillSplitId IS NOT NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_ShipmentChargeBill_SharedSplit')
BEGIN
    ALTER TABLE dbo.ShipmentChargeBill WITH CHECK
        ADD CONSTRAINT FK_ShipmentChargeBill_SharedSplit
            FOREIGN KEY (SourceSharedShipmentChargeBillSplitId)
            REFERENCES dbo.SharedShipmentChargeBillSplit (SharedShipmentChargeBillSplitId);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Shipment_ChargesCompletedBy_Employee')
BEGIN
    ALTER TABLE dbo.Shipment WITH CHECK
        ADD CONSTRAINT FK_Shipment_ChargesCompletedBy_Employee
            FOREIGN KEY (ChargesCompletedBy) REFERENCES dbo.Employee (PayeeId);
END
GO
