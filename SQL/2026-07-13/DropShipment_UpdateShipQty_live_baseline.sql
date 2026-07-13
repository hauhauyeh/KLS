
-- DropShipment_UpdateShipQty
-- Updates ShipQty on drop-ship PO lines and transitions the linked sales
-- order to Transit (StageId=3). No journal entries.

CREATE   PROCEDURE [dbo].[DropShipment_UpdateShipQty]
    @PurchaseId INT,
    @EmpId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IsDropShip BIT = 0;
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

    SET @LockResource =
        'DropShip_UpdateShipQty_'
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
        UPDATE PurchaseDetail SET
            ShipQty = OrdQty0,
            BillQty = OrdQty0
        WHERE PurchaseId = @PurchaseId;

        -- Transition linked sales to Transit
        UPDATE Sales SET
            StageId = 3,
            UpdatedAt = GETUTCDATE()
        WHERE SalesId = @SalesId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END

