SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Shipment_GenerateBill] -- EXEC dbo.Shipment_GenerateBill @ShipmentId=61
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- MVAP_B_GATE_20260714: charge-bill mode creates AP bills from ShipmentChargeBill in Plan C.
    -- Do not also create the old one consolidated shipment AP bill.
    IF EXISTS (SELECT 1 FROM dbo.ShipmentChargeBill WHERE ShipmentId = @ShipmentId)
        RETURN;

    DECLARE @ShipmentTotalCharges DECIMAL(18,2) = 0;
    DECLARE @ExistingBillPurchaseId INT = NULL;
    DECLARE @ExistingBillAmount DECIMAL(18,2) = NULL;
    DECLARE @IsLocked BIT = 0;

    /* 0) If shipment is not assigned to any purchase, skip bill generation */
    IF NOT EXISTS (SELECT 1 FROM dbo.ShipmentPurchase WHERE ShipmentId = @ShipmentId)
        GOTO UpdateShipmentStatus;

    /* 0) If an existing shipment bill is LOCKED, do nothing */
    SELECT TOP (1)
        @ExistingBillPurchaseId = p.PurchaseId,
        @ExistingBillAmount     = COALESCE(p.PurchaseTotal, p.VendorTotal, 0),
        @IsLocked               = p.IsLocked
    FROM dbo.Purchase p
    WHERE p.IsShipment = 1
      AND p.SourceShipmentId = @ShipmentId
    ORDER BY p.PurchaseId DESC;

    IF @IsLocked = 1
        RETURN;

    /* 1) Calculate shipment total charges */
    SELECT @ShipmentTotalCharges = ISNULL(SUM(sc.ChargeAmount), 0)
    FROM dbo.ShipmentCharge sc
    WHERE sc.ShipmentId = @ShipmentId;

    /* 2) Nothing to bill and no existing bill => skip */
    IF @ShipmentTotalCharges = 0 AND @ExistingBillPurchaseId IS NULL
        GOTO UpdateShipmentStatus;

    /* 3) Nothing to bill but existing bill => delete it */
    IF @ShipmentTotalCharges = 0 AND @ExistingBillPurchaseId IS NOT NULL
    BEGIN
        DELETE p
        FROM dbo.Purchase p
        WHERE p.PurchaseId = @ExistingBillPurchaseId;

        GOTO UpdateShipmentStatus;
    END

    /* 4) If bill exists and amount is same => keep shipment allocated */
    IF @ExistingBillPurchaseId IS NOT NULL
       AND ISNULL(@ExistingBillAmount, 0) = @ShipmentTotalCharges
        GOTO AllocateShipment;

    DECLARE @SessionNo INT = NEXT VALUE FOR dbo.Seq_Session;

    DECLARE @PayeeId INT;
    DECLARE @ContainerNumber NVARCHAR(100);
    DECLARE @VendorDocNumber NVARCHAR(100);

    SELECT
        @PayeeId         = s.PayeeId,
        @ContainerNumber = s.ContainerNo,
        @VendorDocNumber = s.DocumentNo
    FROM dbo.Shipment s
    WHERE s.ShipmentId = @ShipmentId;

    IF @PayeeId IS NULL
        THROW 50002, 'Shipment not found or PayeeId is NULL.', 1;

    -- Clean session temp for this session
    DELETE FROM dbo.TempPurchase
    WHERE EmpId = @SessionNo;

    /* 5) Need to update existing bill */
    IF @ExistingBillPurchaseId IS NOT NULL
    BEGIN
        EXEC dbo.[Purchase_Inject]
             @EmpId      = @SessionNo,
             @PayeeId    = @PayeeId,
             @PurchaseId = @ExistingBillPurchaseId,
             @IsPayNow   = 0;

        UPDATE dbo.TempPurchase
        SET ChangeStatus = 'U',
            BillPrice    = @ShipmentTotalCharges,
            FinalPrice   = @ShipmentTotalCharges
        WHERE EmpId = @SessionNo
          AND PurchaseId = @ExistingBillPurchaseId;

        EXEC dbo.[Purchase_PartialUpdate] @ExistingBillPurchaseId, @SessionNo, 1;

        GOTO AllocateShipment;
    END

    /* 6) Create new bill */
    DECLARE @AccountId INT;

    SELECT @AccountId = AccountId
    FROM dbo.Account
    WHERE AccountCode = '@INVC';

    IF @AccountId IS NULL
        THROW 50001, 'AccountCode @INVC not found in Account table.', 1;

    INSERT INTO dbo.TempPurchase
    (
        EmpId, PayeeId, PurchaseId, LineType, ItemId, AccountId,
        OrdQty0, ShipQty, BillQty, OrdQty1, ReceiveQty, FinalQty,
        BillPrice, FinalPrice, LandedCost, FactorToBase
    )
    VALUES
    (
        @SessionNo,
        @PayeeId,
        0,
        'A',
        NULL,
        @AccountId,
        1, 1, 1, 1, 1, 1,
        @ShipmentTotalCharges,
        @ShipmentTotalCharges,
        0,
        1
    );

    DECLARE @NewPurchaseId INT = NULL;

    EXEC dbo.Purchase_Insert
         @PurchaseId      = 0,
         @PayeeId         = @PayeeId,
         @VendorDocNumber = @VendorDocNumber,
         @ContainerNumber = @ContainerNumber,
         @PurchaseDate    = NULL,
         @ArrivalDate     = NULL,
         @InvoiceDate     = NULL,
         @DueDate         = NULL,
         @Notes           = NULL,
         @StageId         = 6,
         @PalletCount     = NULL,
         @EmpId           = @SessionNo,
         @NewPurchaseId   = @NewPurchaseId OUTPUT;

    UPDATE dbo.Purchase
    SET IsShipment       = 1,
        SourceShipmentId = @ShipmentId
    WHERE PurchaseId = @NewPurchaseId;

    GOTO AllocateShipment;

UpdateShipmentStatus:
    EXEC dbo.Shipment_UpdateStatus @ShipmentId;
    RETURN;

AllocateShipment:
    -- 2026-08-10: Shipment Closed status is deprecated. Allocation plus generated AP bill remains Allocated.
    UPDATE dbo.Shipment
    SET Status = 'Allocated',
        UpdatedAt = GETUTCDATE()
    WHERE ShipmentId = @ShipmentId;
    RETURN;
END
GO
