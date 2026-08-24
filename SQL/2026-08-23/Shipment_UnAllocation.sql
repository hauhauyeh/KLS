SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- SCR_C_FK_UNASSIGN_20260710: per-bill redesign - delete this bill's per-bill ShipmentCharge rows
-- before removing the ShipmentPurchase link, else FK_ShipmentCharge_ShipmentPurchase blocks the delete.
CREATE OR ALTER PROCEDURE [dbo].[Shipment_UnAllocation] -- EXEC dbo.Shipment_UnAllocation @ShipmentPurchaseId = 1
    @ShipmentPurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ShipmentId INT;

    SELECT @ShipmentId = sp.ShipmentId
    FROM dbo.ShipmentPurchase sp
    WHERE sp.ShipmentPurchaseId = @ShipmentPurchaseId;

    IF @ShipmentId IS NULL
        THROW 50002, 'Shipment assignment not found.', 1;

    -- 2026-08-23 CONFIRM_CHARGES_COMPLETE:
    -- Preserve this single-link contract, but route the write through the atomic
    -- batch operation so single and batch unassign share exactly one behavior.
    EXEC dbo.Shipment_UnassignPurchases
         @ShipmentId = @ShipmentId,
         @ShipmentPurchaseIds = @ShipmentPurchaseId;
END
