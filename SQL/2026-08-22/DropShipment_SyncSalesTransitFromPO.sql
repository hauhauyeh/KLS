SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[DropShipment_SyncSalesTransitFromPO] -- EXEC dbo.DropShipment_SyncSalesTransitFromPO @PurchaseId=100137
    @PurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @PurchaseId IS NULL
        RETURN;

    DECLARE @IsDropShip BIT;
    DECLARE @SalesId INT;
    DECLARE @PurchaseStageId INT;
    DECLARE @ItemLineCount INT = 0;
    DECLARE @ShipQtyLineCount INT = 0;
    DECLARE @HasShipQty BIT = 0;
    DECLARE @AllShipQty BIT = 0;
    DECLARE @TargetPurchaseStageId INT;
    DECLARE @TargetSalesStageId INT;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);
    DECLARE @SalesLockResource NVARCHAR(200);

    SELECT
        @IsDropShip = IsDropShip,
        @SalesId = DropShipSalesId,
        @PurchaseStageId = StageId
    FROM dbo.Purchase
    WHERE PurchaseId = @PurchaseId;

    IF ISNULL(@IsDropShip, 0) = 0 OR @SalesId IS NULL
        RETURN;

    IF ISNULL(@PurchaseStageId, 0) >= 6
        RETURN;

    SET @LockResource = 'DropShip_POEditStatus_' + CONVERT(NVARCHAR(20), @PurchaseId);

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult = sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 0;

        IF @LockResult < 0
        BEGIN
            RAISERROR('This drop-ship PO status is already being synchronized.', 16, 1);
        END

        -- 2026-08-22 DS-SHIPQTY-STAGE-AUTHORITY: references are informational.
        -- Re-read the link under the canonical PO lock, then lock the linked SO second.
        SET @PurchaseStageId = NULL;

        SELECT
            @PurchaseStageId = StageId,
            @SalesId = DropShipSalesId
        FROM dbo.Purchase
        WHERE PurchaseId = @PurchaseId
          AND ISNULL(IsDropShip, 0) = 1
          AND DropShipSalesId = @SalesId;

        IF @PurchaseStageId IS NULL
        BEGIN
            RAISERROR('Linked drop-ship PO not found for status synchronization.', 16, 1);
        END

        SET @SalesLockResource = 'DropShip_SOEdit_' + CONVERT(NVARCHAR(20), @SalesId);

        EXEC @LockResult = sp_getapplock
            @Resource = @SalesLockResource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 0;

        IF @LockResult < 0
        BEGIN
            RAISERROR('This drop-ship sales order is already being updated.', 16, 1);
        END

        SELECT
            @ItemLineCount = COUNT(1),
            @ShipQtyLineCount = SUM(CASE WHEN ISNULL(ShipQty, 0) > 0 THEN 1 ELSE 0 END)
        FROM dbo.PurchaseDetail
        WHERE PurchaseId = @PurchaseId
          AND LineType = 'I'
          AND ItemId IS NOT NULL;

        SET @HasShipQty = CASE WHEN ISNULL(@ShipQtyLineCount, 0) > 0 THEN 1 ELSE 0 END;
        SET @AllShipQty = CASE WHEN @ItemLineCount > 0 AND @ShipQtyLineCount = @ItemLineCount THEN 1 ELSE 0 END;

        -- 2026-08-22 DS-SHIPQTY-STAGE-AUTHORITY: only positive item ShipQty owns
        -- pre-receipt stage. None positive = Ordered; some = Partial; all = Shipped.
        -- V-Doc# and Cont# remain saved references and never affect stage.
        SET @TargetPurchaseStageId =
            CASE
                WHEN @HasShipQty = 0 THEN 1
                WHEN @AllShipQty = 1 THEN 3
                ELSE 2
            END;

        UPDATE dbo.Purchase
        SET
            StageId = @TargetPurchaseStageId,
            UpdatedAt = GETUTCDATE()
        WHERE PurchaseId = @PurchaseId
          AND ISNULL(IsDropShip, 0) = 1
          AND DropShipSalesId = @SalesId
          AND ISNULL(StageId, 0) < 6
          AND ISNULL(StageId, 0) <> @TargetPurchaseStageId;

        SET @TargetSalesStageId = CASE WHEN @HasShipQty = 1 THEN 2 ELSE 0 END;

        UPDATE dbo.Sales
        SET
            StageId = @TargetSalesStageId,
            UpdatedAt = GETUTCDATE()
        WHERE SalesId = @SalesId
          AND StageId IN (0, 1, 2)
          AND StageId <> @TargetSalesStageId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END

GO
