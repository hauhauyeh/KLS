SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- Restricted existing-line save for a billed drop-ship purchase.
-- EXEC dbo.Purchase_DropShipBillRestrictedUpdate @PurchaseId=177, @EmpId=1
CREATE   PROCEDURE dbo.Purchase_DropShipBillRestrictedUpdate
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

        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.TempPurchase
            WHERE PurchaseId=@PurchaseId AND PayeeId=@PayeeId AND EmpId=@EmpId
        )
            RAISERROR('Drop-ship Bill edit has no item lines.',16,1);

        IF EXISTS
        (
            SELECT PurchaseDetailId
            FROM dbo.TempPurchase
            WHERE PurchaseId=@PurchaseId AND PayeeId=@PayeeId AND EmpId=@EmpId
            GROUP BY PurchaseDetailId
            HAVING PurchaseDetailId IS NULL OR COUNT(*)<>1
        )
            RAISERROR('Drop-ship Bill edit contains an invalid or duplicate line.',16,1);

        IF (SELECT COUNT(*) FROM dbo.TempPurchase WHERE PurchaseId=@PurchaseId AND PayeeId=@PayeeId AND EmpId=@EmpId)
           <> (SELECT COUNT(*) FROM dbo.PurchaseDetail WHERE PurchaseId=@PurchaseId)
            RAISERROR('Drop-ship Bill edit cannot add or delete lines.',16,1);

        IF EXISTS
        (
            SELECT 1
            FROM dbo.TempPurchase t
            LEFT JOIN dbo.PurchaseDetail pd
              ON pd.PurchaseDetailId=t.PurchaseDetailId AND pd.PurchaseId=@PurchaseId
            WHERE t.PurchaseId=@PurchaseId AND t.PayeeId=@PayeeId AND t.EmpId=@EmpId
              AND (pd.PurchaseDetailId IS NULL OR t.LineType<>'I' OR pd.LineType<>'I')
        )
            RAISERROR('Drop-ship Bill edit must keep the existing item lines.',16,1);

        -- Only Notes and synchronized vendor price may differ.
        IF EXISTS
        (
            SELECT
                t.PurchaseDetailId,t.LineId,t.LineType,t.ItemId,t.AccountId,t.ItemUnitId,t.Unit,
                t.IsFree,t.IsOut,t.IsCRCG,t.OrdQty0,t.ShipQty,t.BillQty,t.OrdQty1,t.ReceiveQty,t.FinalQty,
                t.LandedCost,t.ImportCommission,t.FactorToBase,t.ExpiryDate,t.DiscountPercent,
                t.Discount,t.CustomDutyRate,t.TariffPercent,t.DutySharePercent,t.ItemVolume,t.VolumeSharePercent
            FROM dbo.TempPurchase t
            WHERE t.PurchaseId=@PurchaseId AND t.PayeeId=@PayeeId AND t.EmpId=@EmpId
            EXCEPT
            SELECT
                pd.PurchaseDetailId,pd.LineId,pd.LineType,pd.ItemId,pd.AccountId,pd.ItemUnitId,pd.Unit,
                pd.IsFree,pd.IsOut,pd.IsCRCG,pd.OrdQty0,pd.ShipQty,pd.BillQty,pd.OrdQty1,pd.ReceiveQty,pd.FinalQty,
                pd.LandedCost,pd.ImportCommission,pd.FactorToBase,pd.ExpiryDate,pd.DiscountPercent,
                pd.Discount,pd.CustomDutyRate,pd.TariffPercent,pd.DutySharePercent,pd.ItemVolume,pd.VolumeSharePercent
            FROM dbo.PurchaseDetail pd
            WHERE pd.PurchaseId=@PurchaseId
        )
            RAISERROR('Drop-ship Bill edit contains a protected-field change.',16,1);

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
            RAISERROR('Drop-ship vendor price must use one value.',16,1);

        SELECT @HasPriceChange=CONVERT(BIT,MAX(CASE
            WHEN ISNULL(t.BillPrice,0)<>ISNULL(pd.BillPrice,0)
              OR ISNULL(t.FinalPrice,0)<>ISNULL(pd.FinalPrice,0)
              OR ISNULL(t.OrgPrice,0)<>ISNULL(pd.OrgPrice,0)
            THEN 1 ELSE 0 END))
        FROM dbo.TempPurchase t
        INNER JOIN dbo.PurchaseDetail pd ON pd.PurchaseDetailId=t.PurchaseDetailId
        WHERE t.PurchaseId=@PurchaseId AND t.PayeeId=@PayeeId AND t.EmpId=@EmpId;

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
        EXEC dbo.Purchase_CalcTotalAndPercent @PurchaseId,@FinalTotal OUTPUT;
        EXEC dbo.Shipment_Allocation @PurchaseId,NULL;
        EXEC dbo.Shipment_AllocationInventoryClear @PurchaseId;
    END
END
GO
