SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- Restricted existing-line save for drop-ship PO stages 1-3.
-- EXEC dbo.Purchase_DropShipPORestrictedUpdate @PurchaseId=185, @EmpId=1, @CanUpdateShipQty=1
CREATE   PROCEDURE dbo.Purchase_DropShipPORestrictedUpdate
    @PurchaseId INT,
    @EmpId INT,
    @CanUpdateShipQty BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @PayeeId INT;
    DECLARE @PurchaseNumber INT;
    DECLARE @StageId INT;
    DECLARE @IsDropShip BIT;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);
    DECLARE @HasShipQtyChange BIT = 0;
    DECLARE @BillTotal DECIMAL(18,2);
    DECLARE @FinalTotal DECIMAL(18,2);

    SELECT
        @PayeeId = PayeeId,
        @PurchaseNumber = PurchaseNumber,
        @StageId = StageId,
        @IsDropShip = IsDropShip
    FROM dbo.Purchase
    WHERE PurchaseId = @PurchaseId;

    IF @PurchaseNumber IS NULL
    BEGIN
        RAISERROR('Drop-ship purchase order not found.', 16, 1);
        RETURN;
    END

    IF ISNULL(@IsDropShip, 0) = 0 OR @StageId NOT IN (1, 2, 3)
    BEGIN
        RAISERROR('This operation supports drop-ship PO stages 1 through 3 only.', 16, 1);
        RETURN;
    END

    SET @LockResource = 'DropShip_POEditStatus_' + CONVERT(NVARCHAR(20), @PurchaseId);

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult = sys.sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 0;

        IF @LockResult < 0
            RAISERROR('This drop-ship PO is already being updated.', 16, 1);

        -- Re-read the stage under the write lock.
        SELECT
            @PayeeId = PayeeId,
            @StageId = StageId,
            @IsDropShip = IsDropShip
        FROM dbo.Purchase
        WHERE PurchaseId = @PurchaseId;

        IF ISNULL(@IsDropShip, 0) = 0 OR @StageId NOT IN (1, 2, 3)
            RAISERROR('This operation supports drop-ship PO stages 1 through 3 only.', 16, 1);

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.TempPurchase
            WHERE PurchaseId = @PurchaseId
              AND PayeeId = @PayeeId
              AND EmpId = @EmpId
        )
            RAISERROR('Drop-ship PO edit has no item lines.', 16, 1);

        IF EXISTS
        (
            SELECT PurchaseDetailId
            FROM dbo.TempPurchase
            WHERE PurchaseId = @PurchaseId
              AND PayeeId = @PayeeId
              AND EmpId = @EmpId
            GROUP BY PurchaseDetailId
            HAVING PurchaseDetailId IS NULL OR COUNT(*) <> 1
        )
            RAISERROR('Drop-ship PO edit contains an invalid or duplicate line.', 16, 1);

        IF (SELECT COUNT(*) FROM dbo.TempPurchase WHERE PurchaseId=@PurchaseId AND PayeeId=@PayeeId AND EmpId=@EmpId)
           <> (SELECT COUNT(*) FROM dbo.PurchaseDetail WHERE PurchaseId=@PurchaseId)
            RAISERROR('Drop-ship PO edit cannot add or delete lines.', 16, 1);

        IF EXISTS
        (
            SELECT 1
            FROM
            (
                SELECT TempPurchaseId,PurchaseDetailId,LineType FROM dbo.TempPurchase
                WHERE PurchaseId=@PurchaseId AND PayeeId=@PayeeId AND EmpId=@EmpId
            ) t
            FULL JOIN
            (
                SELECT PurchaseDetailId,LineType FROM dbo.PurchaseDetail WHERE PurchaseId=@PurchaseId
            ) pd ON pd.PurchaseDetailId = t.PurchaseDetailId
            WHERE t.TempPurchaseId IS NULL OR pd.PurchaseDetailId IS NULL OR t.LineType <> 'I' OR pd.LineType <> 'I'
        )
            RAISERROR('Drop-ship PO edit must keep the existing item lines.', 16, 1);

        -- Only ShipQty/BillQty, Notes, and synchronized vendor price may differ.
        IF EXISTS
        (
            SELECT
                t.PurchaseDetailId,t.LineId,t.LineType,t.ItemId,t.AccountId,t.ItemUnitId,t.Unit,
                t.IsFree,t.IsOut,t.IsCRCG,t.OrdQty0,t.OrdQty1,t.ReceiveQty,t.FinalQty,
                t.LandedCost,t.ImportCommission,t.FactorToBase,t.ExpiryDate,t.DiscountPercent,
                t.Discount,t.CustomDutyRate,t.TariffPercent,t.DutySharePercent,t.ItemVolume,t.VolumeSharePercent
            FROM dbo.TempPurchase t
            WHERE t.PurchaseId=@PurchaseId AND t.PayeeId=@PayeeId AND t.EmpId=@EmpId
            EXCEPT
            SELECT
                pd.PurchaseDetailId,pd.LineId,pd.LineType,pd.ItemId,pd.AccountId,pd.ItemUnitId,pd.Unit,
                pd.IsFree,pd.IsOut,pd.IsCRCG,pd.OrdQty0,pd.OrdQty1,pd.ReceiveQty,pd.FinalQty,
                pd.LandedCost,pd.ImportCommission,pd.FactorToBase,pd.ExpiryDate,pd.DiscountPercent,
                pd.Discount,pd.CustomDutyRate,pd.TariffPercent,pd.DutySharePercent,pd.ItemVolume,pd.VolumeSharePercent
            FROM dbo.PurchaseDetail pd
            WHERE pd.PurchaseId=@PurchaseId
        )
            RAISERROR('Drop-ship PO edit contains a protected-field change.', 16, 1);

        IF EXISTS
        (
            SELECT 1
            FROM dbo.TempPurchase t
            WHERE t.PurchaseId=@PurchaseId AND t.PayeeId=@PayeeId AND t.EmpId=@EmpId
              AND (ISNULL(t.ShipQty,0) < 0 OR ISNULL(t.ShipQty,0) > ISNULL(t.OrdQty0,0))
        )
            RAISERROR('ShipQty must be between zero and the ordered quantity.', 16, 1);

        IF EXISTS
        (
            SELECT 1
            FROM dbo.TempPurchase t
            WHERE t.PurchaseId=@PurchaseId AND t.PayeeId=@PayeeId AND t.EmpId=@EmpId
              AND ISNULL(t.BillQty,0) <> ISNULL(t.ShipQty,0)
        )
            RAISERROR('BillQty must equal ShipQty for a drop-ship PO.', 16, 1);

        IF EXISTS
        (
            SELECT 1
            FROM dbo.TempPurchase t
            INNER JOIN dbo.PurchaseDetail pd ON pd.PurchaseDetailId=t.PurchaseDetailId
            WHERE t.PurchaseId=@PurchaseId AND t.PayeeId=@PayeeId AND t.EmpId=@EmpId
              AND (ISNULL(t.BillPrice,0)<>ISNULL(t.FinalPrice,0)
                   OR ((ISNULL(t.BillPrice,0)<>ISNULL(pd.BillPrice,0)
                        OR ISNULL(t.FinalPrice,0)<>ISNULL(pd.FinalPrice,0)
                        OR ISNULL(t.OrgPrice,0)<>ISNULL(pd.OrgPrice,0))
                       AND ISNULL(t.BillPrice,0)<>ISNULL(t.OrgPrice,0)))
        )
            RAISERROR('Drop-ship vendor price must use one value.', 16, 1);

        SELECT @HasShipQtyChange = CONVERT(BIT, MAX(CASE
            WHEN ISNULL(t.ShipQty,0) <> ISNULL(pd.ShipQty,0)
              OR ISNULL(t.BillQty,0) <> ISNULL(pd.BillQty,0)
            THEN 1 ELSE 0 END))
        FROM dbo.TempPurchase t
        INNER JOIN dbo.PurchaseDetail pd ON pd.PurchaseDetailId=t.PurchaseDetailId
        WHERE t.PurchaseId=@PurchaseId AND t.PayeeId=@PayeeId AND t.EmpId=@EmpId;

        IF @HasShipQtyChange = 1 AND ISNULL(@CanUpdateShipQty,0) = 0
            RAISERROR('Drop-shipment ShipQty permission is required.', 16, 1);

        UPDATE pd
        SET
            ShipQty = t.ShipQty,
            BillQty = t.BillQty,
            Notes = t.Notes,
            BillPrice = t.BillPrice,
            BillExtTotal = ROUND(ISNULL(t.BillQty,0) * ISNULL(t.BillPrice,0),2),
            FinalPrice = t.FinalPrice,
            FinalExtTotal = ROUND(ISNULL(pd.FinalQty,0) * ISNULL(t.FinalPrice,0),2),
            OrgPrice = t.OrgPrice
        FROM dbo.PurchaseDetail pd
        INNER JOIN dbo.TempPurchase t ON t.PurchaseDetailId=pd.PurchaseDetailId
        WHERE pd.PurchaseId=@PurchaseId
          AND t.PurchaseId=@PurchaseId AND t.PayeeId=@PayeeId AND t.EmpId=@EmpId;

        SELECT
            @BillTotal=ISNULL(SUM(ROUND(ISNULL(BillQty,0)*ISNULL(BillPrice,0),2)),0),
            @FinalTotal=ISNULL(SUM(ROUND(ISNULL(FinalQty,0)*ISNULL(FinalPrice,0),2)),0)
        FROM dbo.PurchaseDetail
        WHERE PurchaseId=@PurchaseId;

        UPDATE dbo.Purchase
        SET VendorTotal=@BillTotal,PurchaseTotal=@FinalTotal,UpdatedAt=GETUTCDATE()
        WHERE PurchaseId=@PurchaseId;

        IF @HasShipQtyChange = 1
            EXEC dbo.DropShipment_SyncSalesTransitFromPO @PurchaseId;

        DELETE dbo.TempPurchase
        WHERE PurchaseId=@PurchaseId AND PayeeId=@PayeeId AND EmpId=@EmpId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
