SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Shipment_ConfirmChargesComplete] -- EXEC dbo.Shipment_ConfirmChargesComplete @ShipmentId = 1, @EmployeePayeeId = 100050
    @ShipmentId INT,
    @EmployeePayeeId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Shipment WHERE ShipmentId = @ShipmentId)
        THROW 50401, 'Shipment_ConfirmChargesComplete: shipment not found.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Employee WHERE PayeeId = @EmployeePayeeId)
        THROW 50402, 'Shipment_ConfirmChargesComplete: employee not found.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.ShipmentPurchase WHERE ShipmentId = @ShipmentId)
        THROW 50403, 'Shipment_ConfirmChargesComplete: shipment has no assigned source bills.', 1;

    IF EXISTS (
        SELECT 1
        FROM dbo.Purchase p
        WHERE ISNULL(p.IsShipment, 0) = 1
          AND p.SourceShipmentId = @ShipmentId
          AND (ISNULL(p.IsLocked, 0) = 1 OR ISNULL(p.PaymentApplied, 0) > 0)
    )
        THROW 50404, 'Shipment_ConfirmChargesComplete: generated AP bill is locked or paid.', 1;

    IF EXISTS (
        SELECT 1
        FROM dbo.ShipmentPurchase sp
        WHERE sp.ShipmentId = @ShipmentId
          AND NOT EXISTS (
              SELECT 1
              FROM dbo.PurchaseDetail pd
              WHERE pd.PurchaseId = sp.PurchaseId
                AND pd.LineType = 'I'
                AND pd.ItemId IS NOT NULL
          )
    )
        THROW 50405, 'Shipment_ConfirmChargesComplete: one or more source bills have no item lines.', 1;

    IF EXISTS (SELECT 1 FROM dbo.ShipmentChargeBill WHERE ShipmentId = @ShipmentId)
       AND EXISTS (
           SELECT 1
           FROM dbo.ShipmentChargeBill scb
           WHERE scb.ShipmentId = @ShipmentId
             AND scb.VendorPayeeId IS NULL
       )
        THROW 50406, 'Shipment_ConfirmChargesComplete: charge bill vendor is required.', 1;

    DECLARE @AssignedBillCount INT;
    DECLARE @ReallocatedCount INT;
    DECLARE @GeneratedOrUpdatedApBillCount INT;

    DECLARE @AffectedPurchases TABLE (PurchaseId INT PRIMARY KEY);

    INSERT INTO @AffectedPurchases (PurchaseId)
    SELECT DISTINCT sp.PurchaseId
    FROM dbo.ShipmentPurchase sp
    WHERE sp.ShipmentId = @ShipmentId;

    SELECT @AssignedBillCount = COUNT(*) FROM @AffectedPurchases;
    SELECT @ReallocatedCount = COUNT(*) FROM @AffectedPurchases;

    BEGIN TRY
        BEGIN TRAN;

        -- Completion confirmation starts from current source data. Charge-bill mode
        -- rebuilds shipment charge summaries before allocation; legacy mode uses
        -- existing ShipmentCharge rows.
        IF EXISTS (SELECT 1 FROM dbo.ShipmentChargeBill WHERE ShipmentId = @ShipmentId)
            EXEC dbo.ShipmentCharge_RebuildFromChargeBills @ShipmentId = @ShipmentId;

        DECLARE @PurchaseId INT;
        DECLARE purchase_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT PurchaseId FROM @AffectedPurchases;

        OPEN purchase_cursor;
        FETCH NEXT FROM purchase_cursor INTO @PurchaseId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.Purchase_Allocation @PurchaseId = @PurchaseId, @RefreshVolume = 0;
            FETCH NEXT FROM purchase_cursor INTO @PurchaseId;
        END

        CLOSE purchase_cursor;
        DEALLOCATE purchase_cursor;

        IF EXISTS (SELECT 1 FROM dbo.ShipmentChargeBill WHERE ShipmentId = @ShipmentId)
            EXEC dbo.Shipment_GenerateChargeBills @ShipmentId = @ShipmentId;
        ELSE
            EXEC dbo.Shipment_GenerateBill @ShipmentId = @ShipmentId;

        SELECT @GeneratedOrUpdatedApBillCount = COUNT(*)
        FROM dbo.Purchase p
        WHERE ISNULL(p.IsShipment, 0) = 1
          AND p.SourceShipmentId = @ShipmentId;

        -- Audit is written last so a partial failure cannot leave the shipment complete.
        UPDATE dbo.Shipment
        SET AreChargesComplete = 1,
            ChargesCompletedAt = GETUTCDATE(),
            ChargesCompletedBy = @EmployeePayeeId,
            UpdatedAt = GETUTCDATE()
        WHERE ShipmentId = @ShipmentId;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'purchase_cursor') >= 0 CLOSE purchase_cursor;
        IF CURSOR_STATUS('local', 'purchase_cursor') >= -1 DEALLOCATE purchase_cursor;
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH

    SELECT
        ShipmentId = @ShipmentId,
        AssignedBillCount = @AssignedBillCount,
        ReallocatedCount = @ReallocatedCount,
        GeneratedOrUpdatedApBillCount = @GeneratedOrUpdatedApBillCount,
        AreChargesComplete = CAST(1 AS BIT),
        ChargesCompletedAt,
        ChargesCompletedBy,
        Status,
        Message = 'Shipment charges confirmed complete.'
    FROM dbo.Shipment
    WHERE ShipmentId = @ShipmentId;
END
