SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- Restricted existing-line save for a billed drop-ship purchase.
-- EXEC dbo.Purchase_DropShipBillRestrictedUpdate @PurchaseId=177, @EmpId=1
CREATE OR ALTER PROCEDURE dbo.Purchase_DropShipBillRestrictedUpdate
    @PurchaseId INT,
    @EmpId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @PayeeId INT;
    DECLARE @PurchaseNumber INT;
    DECLARE @StageId INT;
    DECLARE @IsDropShip BIT;
    DECLARE @IsLocked BIT;
    DECLARE @PaymentApplied DECIMAL(18,2);
    DECLARE @DiscountApplied DECIMAL(18,2);
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);
    DECLARE @HasPriceChange BIT = 0;
    DECLARE @BillTotal DECIMAL(18,2);
    DECLARE @FinalTotal DECIMAL(18,2);
    DECLARE @TxId BIGINT;
    DECLARE @ApAccountId INT;
    DECLARE @CogsAccountId INT;
    DECLARE @CrDeAmount DECIMAL(18,2);
    DECLARE @ExpectedCogsRows INT;
    DECLARE @UpdatedCogsRows INT;

    SELECT
        @PayeeId=PayeeId,
        @PurchaseNumber=PurchaseNumber,
        @StageId=StageId,
        @IsDropShip=IsDropShip,
        @IsLocked=IsLocked,
        @PaymentApplied=PaymentApplied,
        @DiscountApplied=DiscountApplied
    FROM dbo.Purchase
    WHERE PurchaseId=@PurchaseId;

    IF @PurchaseNumber IS NULL
    BEGIN
        RAISERROR('Drop-ship Bill not found.',16,1);
        RETURN;
    END

    IF ISNULL(@IsDropShip,0)=0 OR @StageId<>6
    BEGIN
        RAISERROR('This operation supports billed drop-ship purchases only.',16,1);
        RETURN;
    END

    SET @LockResource='Purchase_PartialUpdate_'+CONVERT(NVARCHAR(20),@PurchaseId);

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult=sys.sp_getapplock
            @Resource=@LockResource,
            @LockMode='Exclusive',
            @LockOwner='Transaction',
            @LockTimeout=0;

        IF @LockResult<0
            RAISERROR('This drop-ship Bill is already being updated.',16,1);

        -- Re-read financial state under the write lock.
        SELECT
            @PayeeId=PayeeId,
            @StageId=StageId,
            @IsDropShip=IsDropShip,
            @IsLocked=IsLocked,
            @PaymentApplied=PaymentApplied,
            @DiscountApplied=DiscountApplied
        FROM dbo.Purchase
        WHERE PurchaseId=@PurchaseId;

        IF ISNULL(@IsDropShip,0)=0 OR @StageId<>6
            RAISERROR('This operation supports billed drop-ship purchases only.',16,1);

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
            RAISERROR('Drop-ship Bill edit has no item lines.',16,1);

        IF EXISTS
        (
            SELECT PurchaseDetailId
            FROM #CartRows
            GROUP BY PurchaseDetailId
            HAVING PurchaseDetailId IS NULL OR COUNT(*)<>1
        )
            RAISERROR('Drop-ship Bill edit contains an invalid or duplicate line.',16,1);

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
                OR ISNULL(c.ShipQty,0) <> ISNULL(s.ShipQty,0)
                OR ISNULL(c.BillQty,0) <> ISNULL(s.BillQty,0)
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
            RAISERROR('Drop-ship Bill edit cannot add or delete lines.',16,1);

        IF EXISTS
        (
            SELECT 1
            FROM #CartRows c
            INNER JOIN #SavedRows s ON s.PurchaseDetailId = c.PurchaseDetailId
            WHERE c.LineType<>'I' OR s.LineType<>'I'
        )
            RAISERROR('Drop-ship Bill edit must keep the existing item lines.',16,1);

        IF EXISTS (SELECT 1 FROM #ChangedRows WHERE HasProtectedChange = 1)
            RAISERROR('Drop-ship Bill edit contains a protected-field change.',16,1);

        -- Legacy restored rows may have OrgPrice NULL. Untouched NULL is valid, but any actual
        -- vendor-price edit must carry one synchronized BillPrice/FinalPrice/OrgPrice value.
        IF EXISTS (SELECT 1 FROM #ChangedRows WHERE HasInvalidVendorPrice = 1)
            RAISERROR('Drop-ship vendor price must use one value.',16,1);

        SELECT @HasPriceChange = CONVERT(BIT, ISNULL(MAX(CONVERT(INT, HasVendorPriceChange)),0))
        FROM #ChangedRows;

        IF @HasPriceChange=1
           AND (ISNULL(@IsLocked,0)=1 OR ISNULL(@PaymentApplied,0)<>0 OR ISNULL(@DiscountApplied,0)<>0)
            RAISERROR('Price cannot be changed after payment or lock. Use the adjustment workflow.',16,1);

        IF @HasPriceChange=1
        BEGIN
            SELECT @TxId=TxId
            FROM dbo.TransactionJournal
            WHERE SourceDocNumber=@PurchaseNumber AND SourceDocType='Purchase';

            SELECT @ApAccountId=AccountId FROM dbo.Account WHERE AccountCode='@AP';
            SELECT @CogsAccountId=AccountId FROM dbo.Account WHERE AccountCode='@COGS';

            IF @TxId IS NULL OR @ApAccountId IS NULL OR @CogsAccountId IS NULL
                RAISERROR('Drop-ship Bill accounting setup is incomplete.',16,1);

            IF EXISTS
            (
                SELECT 1
                FROM dbo.TransactionJournalDetail tjd
                INNER JOIN dbo.Account a ON a.AccountId=tjd.AccountId
                INNER JOIN dbo.PurchaseDetail pd ON pd.PurchaseDetailId=tjd.SourceDetailId
                WHERE tjd.TxId=@TxId AND pd.PurchaseId=@PurchaseId
                  AND a.AccountCode IN ('@INV','@DSCC')
            )
                RAISERROR('Drop-ship Bill journal has unexpected inventory rows.',16,1);

            IF (SELECT COUNT(*) FROM dbo.TransactionJournalDetail WHERE TxId=@TxId AND AccountId=@ApAccountId)<>1
                RAISERROR('Drop-ship Bill journal must have exactly one @AP row.',16,1);

            SELECT @ExpectedCogsRows=COUNT(*)
            FROM dbo.PurchaseDetail
            WHERE PurchaseId=@PurchaseId AND LineType='I' AND ItemId IS NOT NULL;

            IF (SELECT COUNT(*) FROM dbo.TransactionJournalDetail tjd
                INNER JOIN dbo.PurchaseDetail pd ON pd.PurchaseDetailId=tjd.SourceDetailId
                WHERE tjd.TxId=@TxId AND tjd.AccountId=@CogsAccountId AND pd.PurchaseId=@PurchaseId)
               <> @ExpectedCogsRows
                RAISERROR('Drop-ship Bill journal @COGS rows do not match item lines.',16,1);
        END

        UPDATE pd
        SET
            Notes=t.Notes,
            BillPrice=t.BillPrice,
            BillExtTotal=ROUND(ISNULL(pd.BillQty,0)*ISNULL(t.BillPrice,0),2),
            FinalPrice=t.FinalPrice,
            FinalExtTotal=ROUND(ISNULL(pd.FinalQty,0)*ISNULL(t.FinalPrice,0),2),
            OrgPrice=t.OrgPrice
        FROM dbo.PurchaseDetail pd
        INNER JOIN dbo.TempPurchase t ON t.PurchaseDetailId=pd.PurchaseDetailId
        WHERE pd.PurchaseId=@PurchaseId
          AND t.PurchaseId=@PurchaseId AND t.PayeeId=@PayeeId AND t.EmpId=@EmpId;

        IF @HasPriceChange=1
        BEGIN
            SELECT
                @BillTotal=ISNULL(SUM(ROUND(ISNULL(BillQty,0)*ISNULL(BillPrice,0),2)),0),
                @FinalTotal=ISNULL(SUM(ROUND(ISNULL(FinalQty,0)*ISNULL(FinalPrice,0),2)),0)
            FROM dbo.PurchaseDetail
            WHERE PurchaseId=@PurchaseId;

            UPDATE dbo.Purchase
            SET VendorTotal=@BillTotal,PurchaseTotal=@FinalTotal,UpdatedAt=GETUTCDATE()
            WHERE PurchaseId=@PurchaseId;

            EXEC dbo.Fn_Adjust_CrDeAmount @ApAccountId,@FinalTotal,@CrDeAmount OUTPUT;

            UPDATE dbo.TransactionJournalDetail
            SET Amount=@FinalTotal,CrDeAmount=@CrDeAmount
            WHERE TxId=@TxId AND AccountId=@ApAccountId;

            ;WITH CogsRows AS
            (
                SELECT
                    pd.PurchaseDetailId,pd.ItemId,pd.FinalQty,pd.FinalPrice,pd.FactorToBase,
                    ROUND(ISNULL(pd.FinalQty,0)*ISNULL(pd.FinalPrice,0),2) Amount,
                    crde.CrDeAmount
                FROM dbo.PurchaseDetail pd
                CROSS APPLY dbo.Fn_CrDeAmount
                (
                    CONVERT(NVARCHAR(20),@CogsAccountId),
                    ROUND(ISNULL(pd.FinalQty,0)*ISNULL(pd.FinalPrice,0),2)
                ) crde
                WHERE pd.PurchaseId=@PurchaseId AND pd.LineType='I' AND pd.ItemId IS NOT NULL
            )
            UPDATE tjd
            SET
                ItemId=c.ItemId,Qty=c.FinalQty,Price=c.FinalPrice,BillQty=c.FinalQty,
                FactorToBase=c.FactorToBase,Amount=c.Amount,CrDeAmount=c.CrDeAmount
            FROM dbo.TransactionJournalDetail tjd
            INNER JOIN CogsRows c ON c.PurchaseDetailId=tjd.SourceDetailId
            WHERE tjd.TxId=@TxId AND tjd.AccountId=@CogsAccountId;

            SET @UpdatedCogsRows=@@ROWCOUNT;

            IF @UpdatedCogsRows<>@ExpectedCogsRows
                RAISERROR('Drop-ship Bill journal @COGS rows do not match item lines.',16,1);

            IF ABS((SELECT ISNULL(SUM(CrDeAmount),0) FROM dbo.TransactionJournalDetail WHERE TxId=@TxId))>=0.01
                RAISERROR('Drop-ship Bill journal is not balanced after update.',16,1);
        END
        ELSE
        BEGIN
            UPDATE dbo.Purchase SET UpdatedAt=GETUTCDATE() WHERE PurchaseId=@PurchaseId;
        END

        DELETE dbo.TempPurchase
        WHERE PurchaseId=@PurchaseId AND PayeeId=@PayeeId AND EmpId=@EmpId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    IF @HasPriceChange=1
    BEGIN
        -- Keep this post-commit: Shipment_Allocation owns its own transactions and has
        -- multiple commit/return branches, so it cannot be safely nested here.
        EXEC dbo.Purchase_CalcTotalAndPercent @PurchaseId,@FinalTotal OUTPUT;
        EXEC dbo.Shipment_Allocation @PurchaseId,NULL;
        EXEC dbo.Shipment_AllocationInventoryClear @PurchaseId;
    END
END
GO
