SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- SCR_C_FK_UNASSIGN_20260710: per-bill redesign - delete the shipment's ShipmentCharge rows before the
-- ShipmentPurchase mapping delete, else FK_ShipmentCharge_ShipmentPurchase blocks it (per-bill charges).
CREATE OR ALTER PROCEDURE [dbo].[Shipment_Delete] -- EXEC dbo.Shipment_Delete @ShipmentId=61
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ------------------------------------------------------------
    -- 1?? Validate Shipment Exists
    ------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Shipment WHERE ShipmentId = @ShipmentId)
    BEGIN
        RAISERROR('Shipment not found.', 16, 1);
        RETURN;
    END

     -- Guard: block if shipment bill has any payment applied or is locked
     IF EXISTS (
         SELECT 1 FROM dbo.Purchase p
         WHERE p.IsShipment = 1
           AND p.SourceShipmentId = @ShipmentId
           AND (p.IsLocked = 1 OR ISNULL(p.PaymentApplied, 0) > 0)
     )
     BEGIN
         RAISERROR('Cannot delete shipment. Generated shipment AP bill is paid or locked.', 16, 1);
         RETURN;
     END

    BEGIN TRY
        BEGIN TRAN;

    ------------------------------------------------------------
    -- 1 Get All Affected Purchases
    ------------------------------------------------------------
    IF OBJECT_ID('tempdb..#AffectedPurchases') IS NOT NULL
        DROP TABLE #AffectedPurchases;

    SELECT DISTINCT PurchaseId
    INTO #AffectedPurchases
    FROM ShipmentPurchase
    WHERE ShipmentId = @ShipmentId;

    IF OBJECT_ID('tempdb..#GeneratedShipmentPurchases') IS NOT NULL
        DROP TABLE #GeneratedShipmentPurchases;

    SELECT PurchaseId
    INTO #GeneratedShipmentPurchases
    FROM dbo.Purchase
    WHERE IsShipment = 1
      AND SourceShipmentId = @ShipmentId
      AND IsLocked = 0;

    ------------------------------------------------------------
    -- 2 Delete Shipment Allocations
    ------------------------------------------------------------
    DELETE sa
    FROM ShipmentAllocation sa
    INNER JOIN ShipmentCharge sc
        ON sa.ChargeId = sc.ChargeId
    WHERE sc.ShipmentId = @ShipmentId;

    ------------------------------------------------------------
    -- SCR_C_FK_UNASSIGN_20260710: delete charges first (per-bill SA cascade-deletes) so
    -- FK_ShipmentCharge_ShipmentPurchase does not block the mapping delete below.
    ------------------------------------------------------------
    DELETE FROM ShipmentCharge
    WHERE ShipmentId = @ShipmentId;

    ------------------------------------------------------------
    -- 3 Delete Shipment-Purchase Mapping
    ------------------------------------------------------------
    DELETE FROM ShipmentPurchase
    WHERE ShipmentId = @ShipmentId;

    ------------------------------------------------------------
    -- MVAP_C_DELETE_20260714: charge-bill source rows reference Shipment.
    -- Delete them before deleting the Shipment row. Generated AP Purchase
    -- rows are deleted at the end after these FK links are gone.
    ------------------------------------------------------------
    DELETE l
    FROM dbo.ShipmentChargeBillLine l
    JOIN dbo.ShipmentChargeBill b
      ON b.ShipmentChargeBillId = l.ShipmentChargeBillId
    WHERE b.ShipmentId = @ShipmentId;

    DELETE FROM dbo.ShipmentChargeBill
    WHERE ShipmentId = @ShipmentId;

    ------------------------------------------------------------
    -- 6?? Delete Shipment
    ------------------------------------------------------------
    DELETE FROM Shipment
    WHERE ShipmentId = @ShipmentId;

    ------------------------------------------------------------
    -- 7?? Recalculate Each Affected Purchase
    ------------------------------------------------------------
    DECLARE @PurchaseId INT;

    DECLARE purchase_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT PurchaseId FROM #AffectedPurchases;

    OPEN purchase_cursor;
    FETCH NEXT FROM purchase_cursor INTO @PurchaseId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Recalculate landed cost
        EXEC dbo.Shipment_Allocation @PurchaseId;

        -- Repost inventory clear (because landed cost changed)
        EXEC dbo.Shipment_AllocationInventoryClear @PurchaseId;

        FETCH NEXT FROM purchase_cursor INTO @PurchaseId;
    END

    CLOSE purchase_cursor;
    DEALLOCATE purchase_cursor;

    ------------------------------------------------------------
    -- 8 Delete shipment bill
    ------------------------------------------------------------
    DELETE p
    FROM dbo.Purchase p
    JOIN #GeneratedShipmentPurchases g
      ON g.PurchaseId = p.PurchaseId;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'purchase_cursor') >= 0 CLOSE purchase_cursor;
        IF CURSOR_STATUS('local', 'purchase_cursor') >= -1 DEALLOCATE purchase_cursor;
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        ;THROW;
    END CATCH
END
GO
