SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[DropShipment_SyncSalesTransitFromPO] -- EXEC dbo.DropShipment_SyncSalesTransitFromPO @PurchaseId=100137
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
    DECLARE @HasVendorDoc BIT = 0;
    DECLARE @HasContainer BIT = 0;
    DECLARE @ItemLineCount INT = 0;
    DECLARE @ShipQtyLineCount INT = 0;
    DECLARE @HasShipQty BIT = 0;
    DECLARE @AllShipQty BIT = 0;
    DECLARE @IsDirty BIT = 0;
    DECLARE @TargetPurchaseStageId INT;
    DECLARE @TargetSalesStageId INT;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);

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

        SELECT
            @PurchaseStageId = StageId,
            @HasVendorDoc = CASE WHEN NULLIF(LTRIM(RTRIM(VendorDocNumber)), '') IS NOT NULL THEN 1 ELSE 0 END,
            @HasContainer = CASE WHEN NULLIF(LTRIM(RTRIM(ContainerNumber)), '') IS NOT NULL THEN 1 ELSE 0 END
        FROM dbo.Purchase
        WHERE PurchaseId = @PurchaseId
          AND ISNULL(IsDropShip, 0) = 1
          AND DropShipSalesId = @SalesId;

        IF @PurchaseStageId IS NULL
        BEGIN
            RAISERROR('Linked drop-ship PO not found for status synchronization.', 16, 1);
        END

        SELECT
            @ItemLineCount = COUNT(1),
            @ShipQtyLineCount = SUM(CASE WHEN ShipQty IS NOT NULL THEN 1 ELSE 0 END)
        FROM dbo.PurchaseDetail
        WHERE PurchaseId = @PurchaseId
          AND LineType = 'I'
          AND ItemId IS NOT NULL;

        SET @HasShipQty = CASE WHEN ISNULL(@ShipQtyLineCount, 0) > 0 THEN 1 ELSE 0 END;
        SET @AllShipQty = CASE WHEN @ItemLineCount > 0 AND @ShipQtyLineCount = @ItemLineCount THEN 1 ELSE 0 END;
        SET @IsDirty = CASE WHEN @HasVendorDoc = 1 OR @HasContainer = 1 OR @HasShipQty = 1 THEN 1 ELSE 0 END;

        -- 2026-08-13: strict DS PO edit status. The old helper only moved Sales
        -- forward to Transit for PO stage 2/3 or Cont#. This version treats V-Doc#,
        -- Cont#, and any non-null ShipQty as factory state, and can return clean
        -- pre-bill DS documents to Ordered.
        SET @TargetPurchaseStageId =
            CASE
                WHEN @IsDirty = 0 THEN 1
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

        SET @TargetSalesStageId = CASE WHEN @IsDirty = 1 THEN 2 ELSE 0 END;

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
