CREATE PROCEDURE [dbo].[Purchase_Allocation]
    @PurchaseId    INT,
    @RefreshVolume BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.Shipment_Allocation
        @PurchaseId     = @PurchaseId,
        @AllocationType = 'BY_VOLUME',
        @RefreshVolume  = @RefreshVolume;

    EXEC dbo.Shipment_AllocationInventoryClear @PurchaseId;

    DECLARE @ShipmentId INT;

    DECLARE shipment_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT ShipmentId
    FROM   dbo.ShipmentPurchase
    WHERE  PurchaseId = @PurchaseId;

    OPEN shipment_cursor;
    FETCH NEXT FROM shipment_cursor INTO @ShipmentId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.Shipment_GenerateBill @ShipmentId;
        FETCH NEXT FROM shipment_cursor INTO @ShipmentId;
    END

    CLOSE shipment_cursor;
    DEALLOCATE shipment_cursor;
END


