SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- SCR_B_DISPATCH_20260710: route per-bill charges to Shipment_AllocateWithinBill; legacy to Shipment_Allocation.
CREATE OR ALTER PROCEDURE [dbo].[Purchase_Allocation]
    @PurchaseId    INT,
    @RefreshVolume BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- SCR_B_DISPATCH_20260710: per-bill charges (ShipmentPurchaseId NOT NULL) go to the new
    -- within-bill allocator. A shipment/purchase is single-scope (mixed scope is blocked), and the
    -- other (non-orchestrator) direct callers of Shipment_Allocation are protected by its own
    -- ShipmentPurchaseId guard.
    IF EXISTS (
        -- SHIPMENT-level scope: if ANY shipment containing this purchase has ANY per-bill charge
        -- (even on a sibling bill), route the whole purchase to the per-bill path so a new-scope
        -- shipment never runs the legacy cross-vendor allocator on it.
        SELECT 1
        FROM   dbo.ShipmentCharge sc
        WHERE  sc.ShipmentPurchaseId IS NOT NULL
          AND  ISNULL(sc.ChargeAmount, 0) <> 0
          AND  sc.ShipmentId IN (SELECT sp.ShipmentId FROM dbo.ShipmentPurchase sp WHERE sp.PurchaseId = @PurchaseId)
    )
        EXEC dbo.Shipment_AllocateWithinBill @PurchaseId = @PurchaseId, @RefreshVolume = @RefreshVolume;
    -- VENDOR_DIRECT_INVC_20260723: no-shipment same-vendor freight entered as an @INVC
    -- account line should allocate within this bill by item value. The prior wrapper default
    -- forced BY_VOLUME, which skips bills whose item volume basis is missing.
    ELSE IF NOT EXISTS (
        SELECT 1
        FROM   dbo.ShipmentPurchase sp
        WHERE  sp.PurchaseId = @PurchaseId
    )
        EXEC dbo.Shipment_Allocation
            @PurchaseId     = @PurchaseId,
            @AllocationType = 'BY_VALUE',
            @RefreshVolume  = @RefreshVolume;
    ELSE
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


