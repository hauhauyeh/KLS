SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- SCR_C_FK_UNASSIGN_20260710: per-bill redesign - delete this bill's per-bill ShipmentCharge rows
-- before removing the ShipmentPurchase link, else FK_ShipmentCharge_ShipmentPurchase blocks the delete.
CREATE OR ALTER PROCEDURE [dbo].[Shipment_UnAllocation]
    @ShipmentPurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @PurchaseId INT, @ShipmentId INT;

    SELECT @PurchaseId = sp.PurchaseId, @ShipmentId = sp.ShipmentId
    FROM dbo.ShipmentPurchase sp
    WHERE sp.ShipmentPurchaseId = @ShipmentPurchaseId;

    -- Guard: block if shipment bill has any payment applied or is locked
    IF EXISTS (
        SELECT 1 FROM dbo.Purchase p
        WHERE p.IsShipment = 1
          AND p.SourceShipmentId = @ShipmentId
          AND (p.IsLocked = 1 OR ISNULL(p.PaymentApplied, 0) > 0)
    )
        THROW 50002, 'Can not unassign. Shipment bill has payment applied.', 1;

    -- Delete allocations for THIS shipment + THIS purchase
    DELETE sa
    FROM dbo.ShipmentAllocation sa
    INNER JOIN dbo.ShipmentCharge sc ON sc.ChargeId = sa.ChargeId
    INNER JOIN dbo.PurchaseDetail pd ON pd.PurchaseDetailId = sa.PurchaseDetailId
    WHERE sc.ShipmentId = @ShipmentId
      AND pd.PurchaseId = @PurchaseId;

    -- SCR_C_FK_UNASSIGN_20260710: drop this bill's per-bill charges first (their ShipmentAllocation
    -- cascade-deletes via FK_ShipmentAllocation_ShipmentCharge) so the link delete is not FK-blocked.
    DELETE FROM dbo.ShipmentCharge
    WHERE ShipmentPurchaseId = @ShipmentPurchaseId;

    -- Remove the link
    DELETE FROM dbo.ShipmentPurchase
    WHERE ShipmentPurchaseId = @ShipmentPurchaseId;

    -- Re-run allocation for the unassigned purchase (LandedCost -> 0 if no remaining shipments)
    EXEC dbo.Shipment_Allocation @PurchaseId = @PurchaseId, @AllocationType = 'BY_VOLUME';
    EXEC dbo.Shipment_AllocationInventoryClear @PurchaseId = @PurchaseId;

    -- Re-run allocation for ALL remaining linked purchases
    -- (same pattern as Shipment_Delete and Shipment_Update)
    DECLARE @RemainingPurchaseId INT;
    DECLARE remaining_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT PurchaseId FROM dbo.ShipmentPurchase WHERE ShipmentId = @ShipmentId;

    OPEN remaining_cursor;
    FETCH NEXT FROM remaining_cursor INTO @RemainingPurchaseId;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.Shipment_Allocation @PurchaseId = @RemainingPurchaseId, @AllocationType = 'BY_VOLUME';
        EXEC dbo.Shipment_AllocationInventoryClear @PurchaseId = @RemainingPurchaseId;
        FETCH NEXT FROM remaining_cursor INTO @RemainingPurchaseId;
    END
    CLOSE remaining_cursor;
    DEALLOCATE remaining_cursor;

    -- Delete shipment bill if unlocked + no remaining links
    IF EXISTS (
        SELECT 1 FROM dbo.Purchase p
        WHERE p.IsShipment = 1
          AND p.SourceShipmentId = @ShipmentId
          AND p.IsLocked = 0
    )
    AND NOT EXISTS (
        SELECT 1 FROM dbo.ShipmentPurchase sp
        WHERE sp.ShipmentId = @ShipmentId
    )
    BEGIN
        DELETE p FROM dbo.Purchase p
        WHERE p.IsShipment = 1
          AND p.SourceShipmentId = @ShipmentId
          AND p.IsLocked = 0;
    END

    EXEC dbo.Shipment_UpdateStatus @ShipmentId;
END

