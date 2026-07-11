CREATE PROCEDURE [dbo].[Shipment_Delete]
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    ------------------------------------------------------------
    -- 1?? Validate Shipment Exists
    ------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Shipment WHERE ShipmentId = @ShipmentId AND Status<>'Closed')
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
         RAISERROR('Can not delete. Shipment bill has payment applied.', 16, 1);
         RETURN;
     END

    ------------------------------------------------------------
    -- 1 Get All Affected Purchases
    ------------------------------------------------------------
    IF OBJECT_ID('tempdb..#AffectedPurchases') IS NOT NULL 
        DROP TABLE #AffectedPurchases;

    SELECT DISTINCT PurchaseId
    INTO #AffectedPurchases
    FROM ShipmentPurchase
    WHERE ShipmentId = @ShipmentId;

    ------------------------------------------------------------
    -- 2 Delete Shipment Allocations
    ------------------------------------------------------------
    DELETE sa
    FROM ShipmentAllocation sa
    INNER JOIN ShipmentCharge sc 
        ON sa.ChargeId = sc.ChargeId
    WHERE sc.ShipmentId = @ShipmentId;

    ------------------------------------------------------------
    -- 3 Delete Shipment-Purchase Mapping
    ------------------------------------------------------------
    DELETE FROM ShipmentPurchase
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
    DELETE FROM Purchase 
    WHERE IsShipment = 1 AND SourceShipmentId = @ShipmentId AND IsLocked = 0
END


