SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ASB_ASSIGN_GUARD_20260711: enforce one-purchase-one-shipment on the single-assign path.
-- A bill may belong to exactly one shipment; if it is already assigned anywhere, the user
-- must unassign it first. This mirrors the guard on the new batch path (Shipment_AssignBills)
-- so the invariant holds on BOTH assign paths, not only the batch one.
CREATE OR ALTER PROCEDURE [dbo].[Shipment_Assign] -- EXEC dbo.Shipment_Assign @PurchaseId = 12345, @ShipmentIds = '55'

	@PurchaseId INT,
	@ShipmentIds NVARCHAR(MAX)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	-- ASB_ASSIGN_GUARD_20260711: block if this bill is already assigned to any shipment.
	IF EXISTS (SELECT 1 FROM dbo.ShipmentPurchase WHERE PurchaseId = @PurchaseId)
		THROW 50060, 'This bill is already assigned to a shipment. Unassign it first.', 1;

	-- 2026-07-13 DROPSHIP-EXCLUDE: harden single-assign to match Shipment_AssignBills (bill-stage,
	-- non-shipment, unlocked, unpaid). Drop-ship is NOT excluded -- a drop-ship bill may still link
	-- and is allocated by Shipment_ResetCompletionAndReallocate below.
	IF NOT EXISTS (
	    SELECT 1 FROM dbo.Purchase
	    WHERE PurchaseId = @PurchaseId
	      AND StageId = 6
	      AND ISNULL(IsShipment, 0) = 0
	      AND ISNULL(IsLocked, 0) = 0
	      AND ISNULL(PaymentApplied, 0) = 0
	)
	    THROW 50069, 'Bill must be bill-stage, non-shipment, unlocked, and unpaid to join a shipment.', 1;

	-- 2026-07-13 REQUIRE-ITEM-LINES: a bill with no real item line cannot receive landed cost.
	IF NOT EXISTS (
	    SELECT 1 FROM dbo.PurchaseDetail pd
	    WHERE pd.PurchaseId = @PurchaseId AND pd.LineType = 'I' AND pd.ItemId IS NOT NULL
	)
	    THROW 50070, 'Bill has no item lines and cannot be assigned to a shipment.', 1;

    DECLARE @Ids TABLE (ShipmentId INT PRIMARY KEY);

    INSERT INTO @Ids (ShipmentId)
    SELECT DISTINCT TRY_CAST(NULLIF(LTRIM(RTRIM(value)), '') AS INT)
    FROM STRING_SPLIT(ISNULL(@ShipmentIds, ''), ',')
    WHERE TRY_CAST(NULLIF(LTRIM(RTRIM(value)), '') AS INT) IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM @Ids)
        THROW 50071, 'No valid shipment was selected.', 1;

    IF EXISTS (
        SELECT 1
        FROM @Ids i
        LEFT JOIN dbo.Shipment s ON s.ShipmentId = i.ShipmentId
        WHERE s.ShipmentId IS NULL
    )
        THROW 50072, 'One or more selected shipments were not found.', 1;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO dbo.ShipmentPurchase (ShipmentId, PurchaseId)
        SELECT ShipmentId, @PurchaseId
        FROM @Ids;

        -- 2026-08-23 CONFIRM_CHARGES_COMPLETE:
        -- assignment remains immediately allocated, but completion is reset and final
        -- AP charge bill generation is deferred to explicit confirmation.
        DECLARE @ShipmentId INT;
        DECLARE shipment_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT ShipmentId FROM @Ids;

        OPEN shipment_cursor;
        FETCH NEXT FROM shipment_cursor INTO @ShipmentId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC dbo.Shipment_ResetCompletionAndReallocate
                 @ShipmentId = @ShipmentId,
                 @RebuildChargeSummaries = 0,
                 @DeleteGeneratedApBills = 1;

            FETCH NEXT FROM shipment_cursor INTO @ShipmentId;
        END

        CLOSE shipment_cursor;
        DEALLOCATE shipment_cursor;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'shipment_cursor') >= 0 CLOSE shipment_cursor;
        IF CURSOR_STATUS('local', 'shipment_cursor') >= -1 DEALLOCATE shipment_cursor;
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
