
-- DropShipment_UpdateShipQty
-- Drop-ship legacy full ship-qty path. Sets the purchase-side quantity state on the drop-ship PO lines
-- and moves the linked sales order forward to Transit through the shared helper. No journal entries.
-- 2026-07-13: extended from ship/bill-only to the full receive state (adds ReceiveQty/FinalQty
-- + base qty) so a received-but-not-yet-converted PO is qty-complete; DropShipment_ConvertPOToBill
-- later re-applies the same values when it posts.

CREATE   PROCEDURE [dbo].[DropShipment_UpdateShipQty] -- EXEC [dbo].[DropShipment_UpdateShipQty] @PurchaseId=12983, @EmpId=1
    @PurchaseId INT,
    @EmpId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- 2026-07-13: prior "DECLARE @IsDropShip BIT = 0;" -- default dropped so a missing
    -- purchase (NULL) is distinguishable from a real non-drop-ship purchase (0) below.
    DECLARE @IsDropShip BIT;
    DECLARE @PurchaseStageId INT;
    DECLARE @SalesId INT;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);

    -- Validate purchase exists and is drop-ship
    SELECT
        @IsDropShip = IsDropShip,
        @PurchaseStageId = StageId,
        @SalesId = DropShipSalesId
    FROM Purchase
    WHERE PurchaseId = @PurchaseId;

    -- 2026-07-13: fail fast when the purchase row does not exist (previously the BIT=0
    -- default fell through to the misleading "not a drop-ship purchase" message).
    IF @IsDropShip IS NULL
    BEGIN
        RAISERROR('Purchase not found.', 16, 1);
        RETURN;
    END

    IF @IsDropShip = 0
    BEGIN
        RAISERROR('This is not a drop-ship purchase.', 16, 1);
        RETURN;
    END

    IF @PurchaseStageId <> 1
    BEGIN
        RAISERROR('Purchase is not in PO stage. ShipQty can only be updated at PO stage.', 16, 1);
        RETURN;
    END

    IF @SalesId IS NULL
    BEGIN
        RAISERROR('Linked sales order not found on this drop-ship purchase.', 16, 1);
        RETURN;
    END

    -- Validate ShipQty = OrdQty0 per line (partial shipment not supported in v3)
    -- ShipQty values should already be set in PurchaseDetail by the API layer
    -- before calling this proc, via a temp table or direct parameter.
    -- This proc validates and commits the transition.
    -- 2026-07-13: superseded -- this proc now sets the receive quantities directly (below);
    -- there is no API-layer pre-set / temp table involved (full shipment only).

    -- 2026-08-22 DS-SHIPQTY-STAGE-AUTHORITY: all PO progress/full-rebuild paths
    -- use the same PO lock before the linked SO lock taken by the sync helper.
    SET @LockResource =
        'DropShip_POEditStatus_'
        + CONVERT(NVARCHAR(20), @PurchaseId);

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult = sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 0;

        IF @LockResult < 0
        BEGIN
            RAISERROR('This ShipQty update is already being processed.', 16, 1);
        END

        -- Set ShipQty = OrdQty0 for all lines (full shipment only in v3)
        -- 2026-07-13: drop-ship receipt now owns the full purchase-side receive state, not just
        -- ship/bill. Added ReceiveQty/FinalQty (= OrdQty1) to match ConvertPOToBill's Order-branch
        -- fill, so the received PO is qty-complete before (optional) conversion.
        -- Prior (ship/bill only):
        --   UPDATE PurchaseDetail SET ShipQty = OrdQty0, BillQty = OrdQty0 WHERE PurchaseId = @PurchaseId;
        UPDATE PurchaseDetail SET
            ShipQty = OrdQty0,
            BillQty = OrdQty0,
            ReceiveQty = OrdQty1,
            FinalQty = OrdQty1
        WHERE PurchaseId = @PurchaseId;

        -- 2026-07-13: fail fast -- a receipt that touches no PO line must not go on to
        -- transition the sales order (would orphan a stage change with no qty).
        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('No purchase detail rows were updated for this drop-ship receipt.', 16, 1);
        END

        -- 2026-07-13: refresh base qty from ItemUnit (Fn_QtyToBase), qty-only, mirroring
        -- ConvertPOToBill's shared producer. INNER JOIN = item lines only (drop-ship carries no
        -- account lines); keeps BaseReceiveQty/BaseFinalQty consistent with the qty set above.
        UPDATE pd
        SET pd.BaseReceiveQty = dbo.Fn_QtyToBase(pd.ReceiveQty, iu.MultipleToBase, iu.FactorToBase),
            pd.BaseFinalQty   = dbo.Fn_QtyToBase(pd.FinalQty,   iu.MultipleToBase, iu.FactorToBase)
        FROM PurchaseDetail pd
        INNER JOIN ItemUnit iu ON iu.ItemUnitId = pd.ItemUnitId
        WHERE pd.PurchaseId = @PurchaseId;

        -- 2026-08-22 DS-SHIPQTY-STAGE-AUTHORITY: the shared helper now solely owns
        -- Ordered / Partially Shipped / Shipped and linked SO Order / Transit stage.
        -- Replaced old competing write:
        -- UPDATE Purchase SET StageId = 2, UpdatedAt = GETUTCDATE()
        -- WHERE PurchaseId = @PurchaseId;

        EXEC [DropShipment_SyncSalesTransitFromPO] @PurchaseId;

        -- Confirm the linked sales order is now at least Transit or later.
        IF NOT EXISTS
        (
            SELECT 1
            FROM Sales
            WHERE SalesId = @SalesId
              AND StageId >= 2
        )
        BEGIN
            RAISERROR('Linked sales order was not moved to Transit for this drop-ship ship-qty update.', 16, 1);
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END

