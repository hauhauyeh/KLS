SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE dbo.ShipmentCharge_RefreshSingleBillAllocation -- EXEC dbo.ShipmentCharge_RefreshSingleBillAllocation @ShipmentId=70
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PurchaseId INT;
    DECLARE @NormalBillCount INT;

    IF @ShipmentId IS NULL
        RETURN;

    -- Split rows are owned by the allocation split flow. Do not run the legacy
    -- shipment-wide allocator when a shipment already has per-bill charge rows.
    IF EXISTS (
        SELECT 1
        FROM dbo.ShipmentCharge
        WHERE ShipmentId = @ShipmentId
          AND ShipmentPurchaseId IS NOT NULL
          AND ISNULL(ChargeAmount, 0) <> 0
    )
        RETURN;

    SELECT
        @NormalBillCount = COUNT(*),
        @PurchaseId = MIN(p.PurchaseId)
    FROM dbo.ShipmentPurchase sp
    JOIN dbo.Purchase p
      ON p.PurchaseId = sp.PurchaseId
    WHERE sp.ShipmentId = @ShipmentId
      AND ISNULL(p.IsDropShip, 0) = 0
      AND ISNULL(p.IsShipment, 0) = 0
      AND p.StageId = 6;

    IF ISNULL(@NormalBillCount, 0) <> 1 OR @PurchaseId IS NULL
        RETURN;

    EXEC dbo.Shipment_Allocation
         @PurchaseId = @PurchaseId,
         @AllocationType = NULL;

    EXEC dbo.Shipment_AllocationInventoryClear
         @PurchaseId = @PurchaseId;
END
GO
