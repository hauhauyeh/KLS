
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.Shipment_GenerateChargeBills -- EXEC dbo.Shipment_GenerateChargeBills @ShipmentId=61
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Shipment WHERE ShipmentId = @ShipmentId)
        THROW 50101, 'Shipment_GenerateChargeBills: shipment not found.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.ShipmentChargeBill WHERE ShipmentId = @ShipmentId)
        THROW 50102, 'Shipment_GenerateChargeBills: shipment is not in charge-bill mode.', 1;

    EXEC dbo.ShipmentCharge_RebuildFromChargeBills @ShipmentId = @ShipmentId;

    DECLARE @AccountId INT;
    SELECT @AccountId = AccountId
    FROM dbo.Account
    WHERE AccountCode = '@INVC';

    IF @AccountId IS NULL
        THROW 50103, 'Shipment_GenerateChargeBills: AccountCode @INVC not found.', 1;

    -- FK alone only proves the purchase exists. The linked purchase must also be
    -- the generated shipment AP bill for this source charge bill.
    IF EXISTS (
        SELECT 1
        FROM dbo.ShipmentChargeBill scb
        JOIN dbo.Purchase p
          ON p.PurchaseId = scb.PurchaseId
        WHERE scb.ShipmentId = @ShipmentId
          AND (
              ISNULL(p.IsShipment, 0) <> 1
              OR p.SourceShipmentId <> scb.ShipmentId
              OR p.PayeeId <> scb.VendorPayeeId
          )
    )
        THROW 50104, 'Shipment_GenerateChargeBills: linked Purchase does not match charge bill.', 1;

    DECLARE
        @ShipmentChargeBillId INT,
        @VendorPayeeId INT,
        @VendorDocNumber NVARCHAR(100),
        @BillDate DATE,
        @PurchaseId INT,
        @Total DECIMAL(18,2),
        @ExistingPayeeId INT,
        @ExistingAmount DECIMAL(18,2),
        @IsLocked BIT,
        @PaymentApplied DECIMAL(18,2),
        @SessionNo INT,
        @NewPurchaseId INT,
        @ConflictPurchaseId INT,
        @ConflictPurchaseNumber NVARCHAR(50),
        @ConflictSourceShipmentId INT,
        @ConflictContainerNo NVARCHAR(30),
        @ConflictVendorName NVARCHAR(255),
        @DuplicateMessage NVARCHAR(2048);

    DECLARE bill_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            scb.ShipmentChargeBillId,
            scb.VendorPayeeId,
            scb.VendorDocNumber,
            scb.BillDate,
            scb.PurchaseId,
            Total = CAST(ISNULL(SUM(scbl.ChargeAmount), 0) AS DECIMAL(18,2))
        FROM dbo.ShipmentChargeBill scb
        LEFT JOIN dbo.ShipmentChargeBillLine scbl
          ON scbl.ShipmentChargeBillId = scb.ShipmentChargeBillId
        WHERE scb.ShipmentId = @ShipmentId
        GROUP BY
            scb.ShipmentChargeBillId,
            scb.VendorPayeeId,
            scb.VendorDocNumber,
            scb.BillDate,
            scb.PurchaseId
        ORDER BY scb.ShipmentChargeBillId;

    BEGIN TRY
        OPEN bill_cursor;
        FETCH NEXT FROM bill_cursor
        INTO @ShipmentChargeBillId, @VendorPayeeId, @VendorDocNumber, @BillDate, @PurchaseId, @Total;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @VendorPayeeId IS NULL
                THROW 50105, 'Shipment_GenerateChargeBills: VendorPayeeId is required.', 1;

            SET @ExistingPayeeId = NULL;
            SET @ExistingAmount = NULL;
            SET @IsLocked = 0;
            SET @PaymentApplied = 0;
            SET @NewPurchaseId = NULL;

            IF @PurchaseId IS NOT NULL
            BEGIN
                SELECT
                    @ExistingPayeeId = p.PayeeId,
                    @ExistingAmount = COALESCE(p.PurchaseTotal, p.VendorTotal, 0),
                    @IsLocked = ISNULL(p.IsLocked, 0),
                    @PaymentApplied = ISNULL(p.PaymentApplied, 0)
                FROM dbo.Purchase p
                WHERE p.PurchaseId = @PurchaseId;

                IF @IsLocked = 1 OR ISNULL(@PaymentApplied, 0) > 0
                    GOTO NextBill;
            END

            IF NULLIF(LTRIM(RTRIM(ISNULL(@VendorDocNumber, ''))), '') IS NOT NULL
            BEGIN
                SET @ConflictPurchaseNumber = NULL;
                SET @ConflictPurchaseId = NULL;
                SET @ConflictSourceShipmentId = NULL;
                SET @ConflictContainerNo = NULL;
                SET @ConflictVendorName = NULL;
                SET @DuplicateMessage = NULL;

                SELECT TOP (1)
                    @ConflictPurchaseId = p.PurchaseId,
                    @ConflictPurchaseNumber = CONVERT(NVARCHAR(50), p.PurchaseNumber),
                    @ConflictSourceShipmentId = p.SourceShipmentId,
                    @ConflictContainerNo = s.ContainerNo,
                    @ConflictVendorName = pay.PayeeName
                FROM dbo.Purchase p
                LEFT JOIN dbo.Shipment s
                  ON s.ShipmentId = p.SourceShipmentId
                LEFT JOIN dbo.Payee pay
                  ON pay.PayeeId = p.PayeeId
                WHERE p.PayeeId = @VendorPayeeId
                  AND p.VendorDocNumber = @VendorDocNumber
                  AND p.PurchaseId <> ISNULL(@PurchaseId, 0)
                ORDER BY
                    CASE WHEN ISNULL(p.IsShipment, 0) = 1 THEN 0 ELSE 1 END,
                    p.PurchaseId;

                IF @ConflictPurchaseId IS NOT NULL
                BEGIN
                    SET @DuplicateMessage = CONCAT(
                        'Cannot finalize shipment. ',
                        COALESCE(NULLIF(LTRIM(RTRIM(@ConflictVendorName)), ''), CONCAT('Vendor ', @VendorPayeeId)),
                        ' doc #',
                        @VendorDocNumber,
                        ' already exists on AP bill ',
                        COALESCE(@ConflictPurchaseNumber, CONVERT(NVARCHAR(50), @ConflictPurchaseId)),
                        CASE
                            WHEN @ConflictSourceShipmentId IS NOT NULL
                                THEN CONCAT(' for shipment #', @ConflictSourceShipmentId)
                            ELSE ''
                        END,
                        CASE
                            WHEN NULLIF(LTRIM(RTRIM(ISNULL(@ConflictContainerNo, ''))), '') IS NOT NULL
                                THEN CONCAT(' / container ', @ConflictContainerNo)
                            ELSE ''
                        END,
                        '. Change this charge bill doc number, then finalize again.'
                    );

                    THROW 50106, @DuplicateMessage, 1;
                END
            END

            IF @Total = 0
            BEGIN
                IF @PurchaseId IS NOT NULL
                BEGIN
                    BEGIN TRAN;

                    UPDATE dbo.ShipmentChargeBill
                    SET PurchaseId = NULL,
                        UpdatedAt = GETUTCDATE()
                    WHERE ShipmentChargeBillId = @ShipmentChargeBillId;

                    DELETE FROM dbo.Purchase
                    WHERE PurchaseId = @PurchaseId;

                    COMMIT TRAN;
                END

                GOTO NextBill;
            END

            -- If the AP vendor changed, recreate this unlocked generated bill so the
            -- purchase header and existing journal PayeeId cannot drift apart.
            IF @PurchaseId IS NOT NULL AND @ExistingPayeeId <> @VendorPayeeId
            BEGIN
                BEGIN TRAN;

                UPDATE dbo.ShipmentChargeBill
                SET PurchaseId = NULL,
                    UpdatedAt = GETUTCDATE()
                WHERE ShipmentChargeBillId = @ShipmentChargeBillId;

                DELETE FROM dbo.Purchase
                WHERE PurchaseId = @PurchaseId;

                COMMIT TRAN;

                SET @PurchaseId = NULL;
            END

            SET @SessionNo = NEXT VALUE FOR dbo.Seq_Session;

            IF @PurchaseId IS NULL
            BEGIN
                BEGIN TRAN;

                DELETE FROM dbo.TempPurchase
                WHERE EmpId = @SessionNo;

                INSERT INTO dbo.TempPurchase
                (
                    EmpId, PayeeId, PurchaseId, LineType, ItemId, AccountId,
                    OrdQty0, ShipQty, BillQty, OrdQty1, ReceiveQty, FinalQty,
                    BillPrice, BillExtTotal, FinalPrice, FinalExtTotal, LandedCost, FactorToBase
                )
                VALUES
                (
                    @SessionNo, @VendorPayeeId, 0, 'A', NULL, @AccountId,
                    1, 1, 1, 1, 1, 1,
                    @Total, @Total, @Total, @Total, 0, 1
                );

                EXEC dbo.Purchase_Insert
                     @PurchaseId      = 0,
                     @PayeeId         = @VendorPayeeId,
                     @VendorDocNumber = @VendorDocNumber,
                     @ContainerNumber = NULL,
                     @PurchaseDate    = @BillDate,
                     @ArrivalDate     = @BillDate,
                     @InvoiceDate     = @BillDate,
                     @DueDate         = NULL,
                     @Notes           = NULL,
                     @StageId         = 6,
                     @PalletCount     = NULL,
                     @EmpId           = @SessionNo,
                     @NewPurchaseId   = @NewPurchaseId OUTPUT;

                IF @NewPurchaseId IS NULL
                    THROW 50107, 'Shipment_GenerateChargeBills: Purchase_Insert did not return a PurchaseId.', 1;

                UPDATE dbo.Purchase
                SET IsShipment = 1,
                    SourceShipmentId = @ShipmentId
                WHERE PurchaseId = @NewPurchaseId;

                UPDATE dbo.ShipmentChargeBill
                SET PurchaseId = @NewPurchaseId,
                    UpdatedAt = GETUTCDATE()
                WHERE ShipmentChargeBillId = @ShipmentChargeBillId;

                COMMIT TRAN;
            END
            ELSE
            BEGIN
                BEGIN TRAN;

                EXEC dbo.Purchase_Inject
                     @EmpId = @SessionNo,
                     @PayeeId = @VendorPayeeId,
                     @PurchaseId = @PurchaseId,
                     @IsPayNow = 0;

                IF (SELECT COUNT(*) FROM dbo.TempPurchase WHERE EmpId = @SessionNo AND PayeeId = @VendorPayeeId AND PurchaseId = @PurchaseId) <> 1
                    THROW 50108, 'Shipment_GenerateChargeBills: generated AP bill must have exactly one account line.', 1;

                UPDATE dbo.TempPurchase
                SET ChangeStatus = 'U',
                    BillQty = 1,
                    ReceiveQty = 1,
                    FinalQty = 1,
                    BillPrice = @Total,
                    BillExtTotal = @Total,
                    FinalPrice = @Total,
                    FinalExtTotal = @Total
                WHERE EmpId = @SessionNo
                  AND PayeeId = @VendorPayeeId
                  AND PurchaseId = @PurchaseId;

                EXEC dbo.Purchase_PartialUpdate @PurchaseId, @SessionNo, 1;

                UPDATE dbo.Purchase
                SET VendorDocNumber = @VendorDocNumber,
                    PurchaseDate = @BillDate,
                    ArrivalDate = @BillDate,
                    InvoiceDate = @BillDate,
                    UpdatedAt = GETUTCDATE()
                WHERE PurchaseId = @PurchaseId;

                COMMIT TRAN;
            END

NextBill:
            FETCH NEXT FROM bill_cursor
            INTO @ShipmentChargeBillId, @VendorPayeeId, @VendorDocNumber, @BillDate, @PurchaseId, @Total;
        END

        CLOSE bill_cursor;
        DEALLOCATE bill_cursor;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'bill_cursor') >= 0 CLOSE bill_cursor;
        IF CURSOR_STATUS('local', 'bill_cursor') >= -1 DEALLOCATE bill_cursor;
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH

    -- 2026-08-10: Shipment Closed status is deprecated. Charge bill generation leaves shipment Allocated.
    UPDATE dbo.Shipment
    SET Status = 'Allocated',
        UpdatedAt = GETUTCDATE()
    WHERE ShipmentId = @ShipmentId;
END
