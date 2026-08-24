SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Shipment_ResetCompletionAndReallocate] -- EXEC dbo.Shipment_ResetCompletionAndReallocate @ShipmentId = 1, @RebuildChargeSummaries = 0, @DeleteGeneratedApBills = 1
    @ShipmentId INT,
    @RebuildChargeSummaries BIT = 0,
    @DeleteGeneratedApBills BIT = 1,
    @ExtraPurchaseIds NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Shipment WHERE ShipmentId = @ShipmentId)
        THROW 50201, 'Shipment_ResetCompletionAndReallocate: shipment not found.', 1;

    IF @DeleteGeneratedApBills = 1
       AND EXISTS (
           SELECT 1
           FROM dbo.Purchase p
           WHERE ISNULL(p.IsShipment, 0) = 1
             AND p.SourceShipmentId = @ShipmentId
             AND (ISNULL(p.IsLocked, 0) = 1 OR ISNULL(p.PaymentApplied, 0) > 0)
       )
        THROW 50202, 'Generated shipment AP bill is locked or paid. Cannot change shipment charges or assignments.', 1;

    DECLARE @OwnTran BIT = CASE WHEN @@TRANCOUNT = 0 THEN 1 ELSE 0 END;
    DECLARE @AffectedPurchases TABLE (PurchaseId INT PRIMARY KEY);

    INSERT INTO @AffectedPurchases (PurchaseId)
    SELECT DISTINCT sp.PurchaseId
    FROM dbo.ShipmentPurchase sp
    WHERE sp.ShipmentId = @ShipmentId;

    INSERT INTO @AffectedPurchases (PurchaseId)
    SELECT DISTINCT TRY_CAST(NULLIF(LTRIM(RTRIM(value)), '') AS INT)
    FROM STRING_SPLIT(ISNULL(@ExtraPurchaseIds, ''), ',')
    WHERE TRY_CAST(NULLIF(LTRIM(RTRIM(value)), '') AS INT) IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM @AffectedPurchases a
          WHERE a.PurchaseId = TRY_CAST(NULLIF(LTRIM(RTRIM(value)), '') AS INT)
      );

    BEGIN TRY
        IF @OwnTran = 1
            BEGIN TRAN;

        -- Any allocation-affecting edit makes the prior completion audit provisional.
        UPDATE dbo.Shipment
        SET AreChargesComplete = 0,
            ChargesCompletedAt = NULL,
            ChargesCompletedBy = NULL,
            UpdatedAt = GETUTCDATE()
        WHERE ShipmentId = @ShipmentId;

        IF @DeleteGeneratedApBills = 1
        BEGIN
            -- Preserve entered ShipmentChargeBill source rows, but remove their generated AP bill links.
            UPDATE scb
            SET PurchaseId = NULL,
                UpdatedAt = GETUTCDATE()
            FROM dbo.ShipmentChargeBill scb
            JOIN dbo.Purchase p
              ON p.PurchaseId = scb.PurchaseId
            WHERE scb.ShipmentId = @ShipmentId
              AND ISNULL(p.IsShipment, 0) = 1
              AND p.SourceShipmentId = @ShipmentId;

            DELETE p
            FROM dbo.Purchase p
            WHERE ISNULL(p.IsShipment, 0) = 1
              AND p.SourceShipmentId = @ShipmentId;
        END

        IF @RebuildChargeSummaries = 1
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

        EXEC dbo.Shipment_UpdateStatus @ShipmentId;

        IF @OwnTran = 1
            COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'purchase_cursor') >= 0 CLOSE purchase_cursor;
        IF CURSOR_STATUS('local', 'purchase_cursor') >= -1 DEALLOCATE purchase_cursor;
        IF @OwnTran = 1 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
