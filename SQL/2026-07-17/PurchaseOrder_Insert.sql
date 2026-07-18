SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- PurchaseOrder_Insert codex candidate
-- Baseline: live dbo.PurchaseOrder_Insert from KLS_Latest
--
-- Summary:
--   Goal: preserve baseline PO insert/update behavior, while making temp-cart-owned
--   LineId explicit and keeping the narrowed Purchase_CalcTotalAndPercent split safe.
--
-- Improvements:
--   1. XACT_ABORT + TRY/CATCH transaction wrapper
--   2. Applock to reject concurrent/double-submit PO updates/checkouts
--   3. Fail-fast guards for missing payee, temp rows, or missing existing PO
--   4. TempPurchase.LineId is trusted directly as the canonical cart order
--   5. Core totals/base quantities stay inline before post-commit helper work

CREATE OR ALTER PROCEDURE [dbo].[PurchaseOrder_Insert]  

    @PurchaseId INT,
    @PayeeId INT,
    @PurchaseDate DATE,
    @ArrivalDate DATE,
    @Notes NVARCHAR(255),
    @EmpId INT,
    @NewPurchaseId INT OUTPUT,
    @FactorPO NVARCHAR(100) = NULL

AS
BEGIN
    -- Section 1: initialize procedure state and working variables.
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OldPurchaseId INT = @PurchaseId;
    DECLARE @PurchaseNumber INT = 0;
    DECLARE @StageId INT=1;
    DECLARE @TermId INT;
    DECLARE @CreatedAt DATETIME = GETUTCDATE();
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);

    DECLARE @FinalTotal DECIMAL(18,2);
    DECLARE @BillTotal DECIMAL(18,2);

    -- Section 2: validate payee and temp-cart existence for this PO checkout group.
    SELECT @TermId=TermId FROM Payee WHERE PayeeId=@PayeeId;

    IF @TermId IS NULL
    BEGIN
        RAISERROR('Payee not found for PurchaseOrder_Insert.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS
    (
        SELECT 1
        FROM TempPurchase
        WHERE PayeeId = @PayeeId
          AND EmpId = @EmpId
          AND (
                (@PurchaseId > 0 AND PurchaseId = @PurchaseId)
                OR (@PurchaseId = 0 AND PurchaseId = 0)
              )
    )
    BEGIN
        RAISERROR('No temp purchase rows found for this purchase order checkout group.', 16, 1);
        RETURN;
    END

    IF @PurchaseId > 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM Purchase WHERE PurchaseId = @PurchaseId)
        BEGIN
            RAISERROR('Purchase order not found for PurchaseOrder_Insert.', 16, 1);
            RETURN;
        END

        SET @LockResource = 'PurchaseOrder_Insert_' + CAST(@PurchaseId AS NVARCHAR(50));
    END
    ELSE
    BEGIN
        SET @LockResource =
            'PurchaseOrder_Insert_'
            + CAST(@EmpId AS NVARCHAR(50)) + '_'
            + CAST(@PayeeId AS NVARCHAR(50));
    END

    BEGIN TRY
        -- Section 3: start the protected PO checkout/update transaction.
        BEGIN TRANSACTION;

        EXEC @LockResult = sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 0;

        IF @LockResult < 0
        BEGIN
            RAISERROR('This purchase order is already being updated.', 16, 1);
            RETURN;
        END

        -- Section 4: update an existing PO or create a new PO from TempPurchase.
        IF @PurchaseId > 0
        BEGIN
            -- Section 4a: existing PO path.

            DELETE pd
            FROM PurchaseDetail as pd inner join TempPurchase as t ON t.PurchaseDetailId=pd.PurchaseDetailId 
            WHERE t.PayeeId = @PayeeId AND t.EmpId = @EmpId AND t.ChangeStatus = 'D';

            UPDATE PurchaseDetail
            SET  LineId            = t.LineId
                ,[ItemUnitId]      = t.ItemUnitId
                ,[Unit]            = t.Unit
                ,Notes             = t.Notes
                ,IsFree            = t.IsFree
                ,IsOut             = t.IsOut
                ,IsCRCG            = t.IsCRCG
                ,OrdQty0           = t.OrdQty0
                ,ShipQty           = t.ShipQty
                ,BillQty           = t.BillQty
                ,OrdQty1           = t.OrdQty1
                ,ReceiveQty        = t.ReceiveQty
                ,FinalQty          = t.FinalQty
                ,BillPrice         = t.BillPrice
                ,BillExtTotal      = t.BillExtTotal
                ,FinalPrice        = t.FinalPrice
                ,ImportCommission  = t.ImportCommission
                ,FinalExtTotal     = t.FinalExtTotal
                ,FactorToBase      = t.FactorToBase
                ,ExpiryDate        = t.ExpiryDate
                ,DiscountPercent   = t.DiscountPercent
                ,Discount          = t.Discount
                ,OrgPrice          = t.OrgPrice
                ,CustomDutyRate    = t.CustomDutyRate
                ,TariffPercent     = t.TariffPercent
                ,ItemVolume        = t.ItemVolume
            FROM PurchaseDetail as pd inner join TempPurchase as t ON t.PurchaseDetailId=pd.PurchaseDetailId 
            WHERE t.PayeeId = @PayeeId AND t.EmpId = @EmpId AND t.ChangeStatus = 'U';

            INSERT INTO [dbo].[PurchaseDetail]
            (
                [PurchaseId],
                [LineId],
                [LineType],
                [ItemId],
                [AccountId],
                [ItemUnitId],
                [Unit],
                [Notes],
                [IsFree],
                [IsOut],
                [IsCRCG],
                [OrdQty0],
                [ShipQty],
                [BillQty],
                [OrdQty1],
                [ReceiveQty],
                [FinalQty],
                [BillPrice],
                [BillExtTotal],
                [FinalPrice],
                [ImportCommission],
                [FinalExtTotal],
                [FactorToBase],
                [ExpiryDate],
                [DiscountPercent],
                [Discount],
                [OrgPrice],
                [CustomDutyRate],
                [TariffPercent],
                [ItemVolume]
            )
            SELECT 
                @PurchaseId,
                [LineId],
                [LineType],
                [ItemId],
                [AccountId],
                [ItemUnitId],
                [Unit],
                [Notes],
                [IsFree],
                [IsOut],
                [IsCRCG],
                [OrdQty0],
                [ShipQty],
                [BillQty],
                [OrdQty1],
                [ReceiveQty],
                [FinalQty],
                [BillPrice],
                [BillExtTotal],
                [FinalPrice],
                [ImportCommission],
                [FinalExtTotal],
                [FactorToBase],
                [ExpiryDate],
                [DiscountPercent],
                [Discount],
                [OrgPrice],
                [CustomDutyRate],
                [TariffPercent],
                [ItemVolume]
            FROM TempPurchase 
            WHERE PayeeId = @PayeeId AND EmpId = @EmpId AND ChangeStatus = 'I';

        END
        ELSE
        BEGIN
            -- Section 4b: new PO path.

            SET @PurchaseNumber = NEXT VALUE FOR dbo.Seq_PurchaseNumber;

            INSERT INTO [dbo].[Purchase]
            (
                [PurchaseNumber],
                [StageId],
                [PayeeId],
                [PurchaseDate],
                [EnterDate],
                [ArrivalDate],
                [TermId],
                [Notes],
                [FactorPO],
                [IsLocked],
                [IsStartFromPO],
                [CreatedAt]
            )
            VALUES
            (
                @PurchaseNumber,
                @StageId,
                @PayeeId,
                ISNULL(@PurchaseDate,GETDATE()),
                GETDATE(),
                @ArrivalDate,
                @TermId,
                @Notes,
                @FactorPO,
                0,
                1,
                @CreatedAt
            );

            SELECT @PurchaseId = SCOPE_IDENTITY();

            INSERT INTO [dbo].[PurchaseDetail]
            (
                [PurchaseId],
                [LineId],
                [LineType],
                [ItemId],
                [AccountId],
                [ItemUnitId],
                [Unit],
                [Notes],
                [IsFree],
                [IsOut],
                [IsCRCG],
                [OrdQty0],
                [ShipQty],
                [BillQty],
                [OrdQty1],
                [ReceiveQty],
                [FinalQty],
                [BillPrice],
                [BillExtTotal],
                [FinalPrice],
                [ImportCommission],
                [FinalExtTotal],
                [FactorToBase],
                [ExpiryDate],
                [DiscountPercent],
                [Discount],
                [OrgPrice],
                [CustomDutyRate],
                [TariffPercent],
                [ItemVolume]
            )
            SELECT
                @PurchaseId,
                [LineId],
                [LineType],
                [ItemId],
                [AccountId],
                [ItemUnitId],
                [Unit],
                [Notes],
                [IsFree],
                [IsOut],
                [IsCRCG],
                [OrdQty0],
                [ShipQty],
                [BillQty],
                [OrdQty1],
                [ReceiveQty],
                [FinalQty],
                [BillPrice],
                [BillExtTotal],
                [FinalPrice],
                [ImportCommission],
                [FinalExtTotal],
                [FactorToBase],
                [ExpiryDate],
                [DiscountPercent],
                [Discount],
                [OrgPrice],
                [CustomDutyRate],
                [TariffPercent],
                [ItemVolume]
            FROM TempPurchase 
            WHERE EmpId=@EmpId and PayeeId=@PayeeId AND PurchaseId = 0
            ORDER BY LineId;

            -- Section 5: create the minimal journal shell for a new PO.

            DECLARE @AccountId INT;
            DECLARE @TxId BIGINT;
            DECLARE @DocOrder INT;
            DECLARE @DocType NVARCHAR(100) = 'Purchase';

            EXEC [Get_SourceDocOrder] @DocType, @DocOrder OUTPUT;

            INSERT INTO [dbo].[TransactionJournal]
            (
                [TxDate],
                [TxTime],
                [SourceDocOrder],
                [SourceDocType],
                [SourceDocNumber]
            )
            VALUES
            (
                @PurchaseDate,
                GETUTCDATE(),
                @DocOrder,
                @DocType,
                @PurchaseNumber
            );

            SELECT @TxId = SCOPE_IDENTITY();

            SELECT @AccountId=AccountId FROM Account WHERE AccountCode='@AP';

            INSERT INTO TransactionJournalDetail
            (
                [TxId],
                [AccountId],
                [PayeeId],
                [Amount],
                [CrDeAmount]
            )
            VALUES
            (
                @TxId,
                @AccountId,
                @PayeeId,
                0,
                0
            );
        END

        -- Section 6: keep totals/base qty logic unchanged

        SELECT
            @BillTotal = ISNULL(SUM(ROUND(BillQty * BillPrice, 2)), 0),
            @FinalTotal = ISNULL(SUM(ROUND(FinalQty * FinalPrice, 2)), 0)
        FROM PurchaseDetail
        WHERE PurchaseId = @PurchaseId;

        -- 2026-07-05 (Phase B): base qty derives from ItemUnitId -> ItemUnit (single source of
        -- truth) via dbo.Fn_QtyToBase, retiring the FactorToBase snapshot read. Set-based INNER
        -- JOIN = item lines only; account lines (no ItemUnitId) are not updated -> keep base qty
        -- (they feed no @INV; a PO posts no inventory anyway). PO base qty IS read downstream
        -- (PO->Bill, history, incoming-stock) so it must be ItemUnit-derived. Identity today
        -- (all MultipleToBase=1 => qty/factor). Prior block:
        -- UPDATE PurchaseDetail
        -- SET
        --     BaseReceiveQty = ROUND(ReceiveQty / FactorToBase, 6),
        --     BaseFinalQty = ROUND(FinalQty / FactorToBase, 6)
        -- WHERE PurchaseId = @PurchaseId;
        UPDATE pd
        SET
            pd.BaseReceiveQty = dbo.Fn_QtyToBase(pd.ReceiveQty, iu.MultipleToBase, iu.FactorToBase),
            pd.BaseFinalQty = dbo.Fn_QtyToBase(pd.FinalQty, iu.MultipleToBase, iu.FactorToBase)
        FROM PurchaseDetail pd
        INNER JOIN ItemUnit iu ON iu.ItemUnitId = pd.ItemUnitId
        WHERE pd.PurchaseId = @PurchaseId;

        UPDATE Purchase
        SET
            VendorTotal = @BillTotal,
            PurchaseTotal = @FinalTotal,
            FactorPO = COALESCE(@FactorPO, FactorPO),
            UpdatedAt = GETUTCDATE()
        WHERE PurchaseId = @PurchaseId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    -- Section 7: post-commit helper
    EXEC [Purchase_CalcTotalAndPercent] @PurchaseId,@FinalTotal OUTPUT;

    SET @NewPurchaseId=@PurchaseId;

    -- Section 8: clear temp-cart rows only after the PO write succeeds.
    DELETE FROM TempPurchase WHERE PayeeId=@PayeeId AND EmpId=@EmpId;

END
