SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ASB_ASSIGN_GUARD_20260711: enforce one-purchase-one-shipment on the single-assign path.
-- A bill may belong to exactly one shipment; if it is already assigned anywhere, the user
-- must unassign it first. This mirrors the guard on the new batch path (Shipment_AssignBills)
-- so the invariant holds on BOTH assign paths, not only the batch one.
CREATE OR ALTER PROCEDURE [dbo].[Shipment_Assign]   -- EXEC dbo.Shipment_Assign @PurchaseId=12345, @ShipmentIds='55'

	@PurchaseId INT,
	@ShipmentIds NVARCHAR(MAX)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- ASB_ASSIGN_GUARD_20260711: block if this bill is already assigned to any shipment.
	IF EXISTS (SELECT 1 FROM dbo.ShipmentPurchase WHERE PurchaseId = @PurchaseId)
		THROW 50060, 'This bill is already assigned to a shipment. Unassign it first.', 1;

	-- 2026-07-13 DROPSHIP-EXCLUDE: harden single-assign to match Shipment_AssignBills (bill-stage,
	-- non-shipment, unlocked, unpaid). Drop-ship is NOT excluded -- a drop-ship bill may still link;
	-- it just skips allocation/clear below.
	IF NOT EXISTS (
	    SELECT 1 FROM dbo.Purchase
	    WHERE PurchaseId = @PurchaseId
	      AND StageId = 6
	      AND ISNULL(IsShipment, 0) = 0
	      AND ISNULL(IsLocked, 0) = 0
	      AND ISNULL(PaymentApplied, 0) = 0
	)
	    THROW 50069, 'Bill must be bill-stage, non-shipment, unlocked, and unpaid to join a shipment.', 1;

	IF @ShipmentIds IS NOT NULL AND LTRIM(RTRIM(@ShipmentIds)) <> ''
	BEGIN
		INSERT INTO ShipmentPurchase (ShipmentId, PurchaseId)
		SELECT CAST(value AS INT) AS ShipmentId, @PurchaseId
		FROM STRING_SPLIT(@ShipmentIds, ',');
	END

	-- 2026-07-13 DROPSHIP-EXCLUDE: drop-ship bills link only -- never allocate landed cost or run
	-- inventory clear (no @INV receipt; COGS is document-level). Prior (unconditional):
	--   EXEC dbo.Shipment_Allocation @PurchaseId = @PurchaseId, @AllocationType = NULL;
	--   EXEC dbo.Shipment_AllocationInventoryClear @PurchaseId;
	IF NOT EXISTS (SELECT 1 FROM dbo.Purchase WHERE PurchaseId = @PurchaseId AND ISNULL(IsDropShip, 0) = 1)
	BEGIN
	    EXEC dbo.Shipment_Allocation @PurchaseId = @PurchaseId, @AllocationType = NULL;
	    EXEC dbo.Shipment_AllocationInventoryClear @PurchaseId;
	END

	------------------------------------------------------------
    -- Recalculate Each Affected Shipment status
    ------------------------------------------------------------
    DECLARE @ShipmentId INT;

    DECLARE shipment_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT ShipmentId FROM ShipmentPurchase WHERE PurchaseId = @PurchaseId;

    OPEN shipment_cursor;
    FETCH NEXT FROM shipment_cursor INTO @ShipmentId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        --EXEC dbo.Shipment_UpdateStatus @ShipmentId

        EXEC dbo.Shipment_GenerateBill @ShipmentId;

        FETCH NEXT FROM shipment_cursor INTO @ShipmentId;
    END

    CLOSE shipment_cursor;
    DEALLOCATE shipment_cursor;
END
GO
