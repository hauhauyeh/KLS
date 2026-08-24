
CREATE PROCEDURE [dbo].[Shipment_Update]
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------
    -- Recalculate Each Affected Purchase
    ------------------------------------------------------------
    DECLARE @PurchaseId INT;

    DECLARE purchase_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT PurchaseId FROM ShipmentPurchase WHERE ShipmentId = @ShipmentId;

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

    EXEC dbo.Shipment_GenerateBill @ShipmentId;
END

