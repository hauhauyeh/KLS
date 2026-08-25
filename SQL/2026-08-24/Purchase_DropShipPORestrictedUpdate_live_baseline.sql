

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

        SELECT
            TempPurchaseId,PurchaseDetailId,LineId,LineType,ItemId,AccountId,ItemUnitId,Unit,
            Notes,IsFree,IsOut,IsCRCG,OrdQty0,ShipQty,BillQty,OrdQty1,ReceiveQty,FinalQty,
            BillPrice,FinalPrice,LandedCost,ImportCommission,FactorToBase,ExpiryDate,
            DiscountPercent,Discount,OrgPrice,CustomDutyRate,TariffPercent,DutySharePercent,
            ItemVolume,VolumeSharePercent
        INTO #CartRows
        FROM dbo.TempPurchase
        WHERE PurchaseId=@PurchaseId AND PayeeId=@PayeeId AND EmpId=@EmpId;

        SELECT
            PurchaseDetailId,LineId,LineType,ItemId,AccountId,ItemUnitId,Unit,
            Notes,IsFree,IsOut,IsCRCG,OrdQty0,ShipQty,BillQty,OrdQty1,ReceiveQty,FinalQty,
            BillPrice,FinalPrice,LandedCost,ImportCommission,FactorToBase,ExpiryDate,
            DiscountPercent,Discount,OrgPrice,CustomDutyRate,TariffPercent,DutySharePercent,
            ItemVolume,VolumeSharePercent
        INTO #SavedRows
        FROM dbo.PurchaseDetail
        WHERE PurchaseId=@PurchaseId;

        IF NOT EXISTS (SELECT 1 FROM #CartRows)
            RAISERROR('Drop-ship PO edit has no item lines.', 16, 1);

        IF EXISTS
        (
            SELECT PurchaseDetailId
            FROM #CartRows
            GROUP BY PurchaseDetailId
            HAVING PurchaseDetailId IS NULL OR COUNT(*) <> 1
        )
            RAISERROR('Drop-ship PO edit contains an invalid or duplicate line.', 16, 1);

        SELECT
            c.TempPurchaseId,
            CartPurchaseDetailId = c.PurchaseDetailId,
            SavedPurchaseDetailId = s.PurchaseDetailId,
            HasProtectedChange = CONVERT(BIT, CASE WHEN
                   ISNULL(c.LineId,-1) <> ISNULL(s.LineId,-1)
                OR ISNULL(c.LineType,'') <> ISNULL(s.LineType,'')
                OR ISNULL(c.ItemId,-1) <> ISNULL(s.ItemId,-1)
                OR ISNULL(c.AccountId,-1) <> ISNULL(s.AccountId,-1)
                OR ISNULL(c.ItemUnitId,-1) <> ISNULL(s.ItemUnitId,-1)
                OR ISNULL(c.Unit,'') <> ISNULL(s.Unit,'')
                OR ISNULL(c.IsFree,0) <> ISNULL(s.IsFree,0)
                OR ISNULL(c.IsOut,0) <> ISNULL(s.IsOut,0)
                OR ISNULL(c.IsCRCG,0) <> ISNULL(s.IsCRCG,0)
                OR ISNULL(c.OrdQty0,0) <> ISNULL(s.OrdQty0,0)
                OR ISNULL(c.OrdQty1,0) <> ISNULL(s.OrdQty1,0)
                OR ISNULL(c.ReceiveQty,0) <> ISNULL(s.ReceiveQty,0)
                OR ISNULL(c.FinalQty,0) <> ISNULL(s.FinalQty,0)
                OR ISNULL(c.LandedCost,0) <> ISNULL(s.LandedCost,0)
                OR ISNULL(c.ImportCommission,0) <> ISNULL(s.ImportCommission,0)
                OR ISNULL(c.FactorToBase,0) <> ISNULL(s.FactorToBase,0)
                OR ISNULL(c.ExpiryDate,'19000101') <> ISNULL(s.ExpiryDate,'19000101')
                OR ISNULL(c.DiscountPercent,0) <> ISNULL(s.DiscountPercent,0)
                OR ISNULL(c.Discount,0) <> ISNULL(s.Discount,0)
                OR ISNULL(c.CustomDutyRate,0) <> ISNULL(s.CustomDutyRate,0)
                OR ISNULL(c.TariffPercent,0) <> ISNULL(s.TariffPercent,0)
                OR ISNULL(c.DutySharePercent,0) <> ISNULL(s.DutySharePercent,0)
                OR ISNULL(c.ItemVolume,0) <> ISNULL(s.ItemVolume,0)
                OR ISNULL(c.VolumeSharePercent,0) <> ISNULL(s.VolumeSharePercent,0)
                THEN 1 ELSE 0 END),
            HasShipQtyChange = CONVERT(BIT, CASE WHEN
                   ISNULL(c.ShipQty,0) <> ISNULL(s.ShipQty,0)
                OR ISNULL(c.BillQty,0) <> ISNULL(s.BillQty,0)
                THEN 1 ELSE 0 END),
            HasCommentChange = CONVERT(BIT, CASE WHEN
                   ISNULL(c.Notes,'') <> ISNULL(s.Notes,'')
                THEN 1 ELSE 0 END),
            HasVendorPriceChange = CONVERT(BIT, CASE WHEN
                   ISNULL(c.BillPrice,0) <> ISNULL(s.BillPrice,0)
                OR ISNULL(c.FinalPrice,0) <> ISNULL(s.FinalPrice,0)
                OR (s.OrgPrice IS NOT NULL AND ISNULL(c.OrgPrice,0) <> ISNULL(s.OrgPrice,0))
                THEN 1 ELSE 0 END),
            HasInvalidVendorPrice = CONVERT(BIT, CASE WHEN
                   ISNULL(c.BillPrice,0) <> ISNULL(c.FinalPrice,0)
                OR ((ISNULL(c.BillPrice,0) <> ISNULL(s.BillPrice,0)
                     OR ISNULL(c.FinalPrice,0) <> ISNULL(s.FinalPrice,0)
                     OR (s.OrgPrice IS NOT NULL AND ISNULL(c.OrgPrice,0) <> ISNULL(s.OrgPrice,0)))
                    AND ISNULL(c.BillPrice,0) <> ISNULL(c.OrgPrice,0))
                OR (s.OrgPrice IS NULL AND c.OrgPrice IS NOT NULL AND ISNULL(c.BillPrice,0) <> ISNULL(c.OrgPrice,0))
                THEN 1 ELSE 0 END),
            HasInvalidShipQty = CONVERT(BIT, CASE WHEN
                   ISNULL(c.ShipQty,0) < 0
                OR ISNULL(c.ShipQty,0) > ISNULL(c.OrdQty0,0)
                THEN 1 ELSE 0 END),
            HasBillQtyMismatch = CONVERT(BIT, CASE WHEN
                   ISNULL(c.BillQty,0) <> ISNULL(c.ShipQty,0)
                THEN 1 ELSE 0 END)
        INTO #ChangedRows
        FROM #CartRows c
        FULL JOIN #SavedRows s ON s.PurchaseDetailId = c.PurchaseDetailId;

        IF EXISTS
        (
            SELECT 1
            FROM #ChangedRows
            WHERE TempPurchaseId IS NULL OR SavedPurchaseDetailId IS NULL
        )
            RAISERROR('Drop-ship PO edit cannot add or delete lines.', 16, 1);

        IF EXISTS
        (
            SELECT 1
            FROM #CartRows c
            INNER JOIN #SavedRows s ON s.PurchaseDetailId = c.PurchaseDetailId
            WHERE c.LineType <> 'I' OR s.LineType <> 'I'
        )
            RAISERROR('Drop-ship PO edit must keep the existing item lines.', 16, 1);

        IF EXISTS (SELECT 1 FROM #ChangedRows WHERE HasProtectedChange = 1)
            RAISERROR('Drop-ship PO edit contains a protected-field change.', 16, 1);

        IF EXISTS (SELECT 1 FROM #ChangedRows WHERE HasInvalidShipQty = 1)
            RAISERROR('ShipQty must be between zero and the ordered quantity.', 16, 1);

        IF EXISTS (SELECT 1 FROM #ChangedRows WHERE HasBillQtyMismatch = 1)
            RAISERROR('BillQty must equal ShipQty for a drop-ship PO.', 16, 1);

        -- Legacy restored rows may have OrgPrice NULL. Untouched NULL is valid, but any actual
        -- vendor-price edit must carry one synchronized BillPrice/FinalPrice/OrgPrice value.
        IF EXISTS (SELECT 1 FROM #ChangedRows WHERE HasInvalidVendorPrice = 1)
            RAISERROR('Drop-ship vendor price must use one value.', 16, 1);

        SELECT @HasShipQtyChange = CONVERT(BIT, ISNULL(MAX(CONVERT(INT, HasShipQtyChange)),0))
        FROM #ChangedRows;

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