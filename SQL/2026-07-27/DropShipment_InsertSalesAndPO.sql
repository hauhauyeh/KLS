
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- DropShipment_InsertSalesAndPO
-- Creates or updates a drop-ship sales order (StageId=0) and its linked
-- purchase PO (StageId=1) in one transaction. No journal entries are created.
--
-- First save: insert Sales + SalesDetail from TempSales, then copy lines to
-- TempPurchase and insert Purchase + PurchaseDetail.
-- Edit mode: update existing Sales/SalesDetail, then full-replace linked
-- PurchaseDetail from current SalesDetail via TempPurchase.

-- 2026-07-13 DROPSHIP-ITEMONLY: the generated vendor PO now carries ITEM lines only (SalesDetail.LineType='I');
--   account lines (LineType='A': customer shipping charge / GL account lines) are excluded. One WHERE predicate
--   covers create + edit (same TempPurchase INSERT...SELECT). See plan-dropship-3-exclude-non-item.md.
-- 2026-07-14 DROPSHIP-ARRIVALDATE: selected drop-ship ShipDate is the customer-received date;
--   keep Purchase.ArrivalDate aligned with Sales.ShipDate. Old behavior omitted Purchase.ArrivalDate and left it NULL.
-- 2026-07-18 PO-PURECOST: PO line BillPrice/FinalPrice now default to RecentBaseCost (pure vendor cost,
--   no landed cost) with RecentCost fallback for units not yet backfilled. Old: ISNULL(i.RecentCost, 0).
--   See plan/po-item-base-cost-default-v2.md step 6.
-- 2026-07-21 DROPSHIP-CPO: optional Customer PO is captured on the Sales side while Factory PO stays on Purchase.
-- 2026-07-22 BACKORDER-DROPSHIP-SOURCE-LINK: optional SourceSalesId stores the new backorder SO's ParentSalesNumber.
-- EXEC dbo.DropShipment_InsertSalesAndPO @SalesId=0, @PayeeId=1, @VendorPayeeId=2, @ShipDate='2026-07-21', @ShipRoute=NULL, @Instruction='Web', @EmpId=1, @PurchaseDate=NULL, @NewSalesId=0, @NewPurchaseId=0, @FactorPO='FPO-1', @CustPONumber='CPO-1', @SourceSalesId=NULL;
CREATE OR ALTER PROCEDURE [dbo].[DropShipment_InsertSalesAndPO]
    @SalesId INT,
    @PayeeId INT,
    @VendorPayeeId INT,
    @ShipDate DATE,
    @ShipRoute NVARCHAR(10),
    @Instruction NVARCHAR(300) = 'Web',
    @EmpId INT,
    @PurchaseDate DATE = NULL,
    @NewSalesId INT OUTPUT,
    @NewPurchaseId INT OUTPUT,
    @FactorPO NVARCHAR(100) = NULL,
    @CustPONumber NVARCHAR(100) = NULL,
    @SourceSalesId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @FactorPO = NULLIF(UPPER(LTRIM(RTRIM(@FactorPO))), '');
    SET @CustPONumber = NULLIF(UPPER(LTRIM(RTRIM(@CustPONumber))), '');

    DECLARE @SalesNumber INT;
    DECLARE @PurchaseNumber INT;
    DECLARE @PurchaseId INT;
    DECLARE @SalesDate DATETIME = GETUTCDATE();
    DECLARE @BillId INT;
    DECLARE @TaxRate DECIMAL(18,4);
    DECLARE @SalesRepId INT;
    DECLARE @ShippingCarrierId INT;
    DECLARE @IsStatementPrint BIT;
    DECLARE @TermId INT;
    DECLARE @VendorTermId INT;
    DECLARE @IsEdit BIT = 0;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);
    DECLARE @SubTotal DECIMAL(18,2);
    DECLARE @TaxableTotal DECIMAL(18,2);
    DECLARE @TaxTotal DECIMAL(18,2);
    DECLARE @SalesTotal DECIMAL(18,2);
    DECLARE @BillTotal DECIMAL(18,2);
    DECLARE @SalesTotalOut DECIMAL(18,2);
    DECLARE @FinalTotal DECIMAL(18,2);
    DECLARE @ParentSalesNumber INT;
    DECLARE @SalesDocNumber NVARCHAR(50);

    SET @PurchaseDate = ISNULL(@PurchaseDate, CAST(GETDATE() AS DATE));

    IF @SalesId>0
        SELECT @VendorPayeeId = PayeeId 
        FROM Purchase WHERE PurchaseId = (SELECT DropShipPurchaseId FROM Sales WHERE SalesId = @SalesId)

    IF @SourceSalesId IS NOT NULL
    BEGIN
        IF @SalesId > 0
        BEGIN
            RAISERROR('Backorder drop-ship checkout must create a new sales order.', 16, 1);
            RETURN;
        END

        SELECT @ParentSalesNumber = SalesNumber
        FROM dbo.Sales
        WHERE SalesId = @SourceSalesId;

        IF @ParentSalesNumber IS NULL
        BEGIN
            RAISERROR('Source sales order not found.', 16, 1);
            RETURN;
        END
    END

    -- Validate vendor
    SELECT @VendorTermId = TermId FROM Payee WHERE PayeeId = @VendorPayeeId;
    IF @VendorTermId IS NULL
    BEGIN
        RAISERROR('Vendor payee not found.', 16, 1);
        RETURN;
    END

    -- Validate customer
    SELECT
        @TermId = TermId,
        @BillId = ISNULL(BillId, p.PayeeId),
        @TaxRate = TaxRate,
        @SalesRepId = ISNULL(SalesRepId, @EmpId),
        @ShippingCarrierId = ShippingCarrierId,
        @IsStatementPrint = IsStatementPrint,
        @ShipRoute = ISNULL(@ShipRoute, DefaultRoute)
    FROM Payee AS p
    INNER JOIN Customer AS c ON p.PayeeId = c.PayeeId
    WHERE p.PayeeId = @PayeeId;

    IF @TermId IS NULL
    BEGIN
        RAISERROR('Customer payee not found.', 16, 1);
        RETURN;
    END

    -- Check if editing an existing drop-ship order
    IF @SalesId > 0
    BEGIN
        DECLARE @ExistingStageId INT;
        DECLARE @ExistingIsDropShip BIT;
        DECLARE @ExistingPurchaseId INT;

        SELECT
            @ExistingStageId = StageId,
            @ExistingIsDropShip = IsDropShip,
            @ExistingPurchaseId = DropShipPurchaseId
        FROM Sales
        WHERE SalesId = @SalesId;

        IF @ExistingIsDropShip IS NULL
        BEGIN
            RAISERROR('Sales order not found.', 16, 1);
            RETURN;
        END

        IF @ExistingIsDropShip = 1 AND @ExistingStageId >= 3
        BEGIN
            RAISERROR('This drop-ship order is in Transit or beyond and cannot be edited.', 16, 1);
            RETURN;
        END

        IF @ExistingIsDropShip = 1 AND @ExistingPurchaseId IS NOT NULL
        BEGIN
            SET @IsEdit = 1;
            SET @PurchaseId = @ExistingPurchaseId;
        END
    END

    -- Validate TempSales has rows
    IF NOT EXISTS (
        SELECT 1 FROM TempSales
        WHERE EmpId = @EmpId AND PayeeId = @PayeeId
          AND SalesId = CASE WHEN @IsEdit = 1 THEN @SalesId ELSE 0 END
          AND IsStrike = 0
    )
    BEGIN
        RAISERROR('No rows found for this checkout group.', 16, 1);
        RETURN;
    END

    -- Build lock resource
    SET @LockResource =
        'DropShip_InsertSalesAndPO_'
        + CONVERT(NVARCHAR(20), @EmpId) + '_'
        + CONVERT(NVARCHAR(20), @PayeeId) + '_'
        + CONVERT(NVARCHAR(20), @VendorPayeeId);

    IF @ShipDate IS NULL
        EXEC dbo.Fn_Calc_NextShipDate @PayeeId, @ShipDate OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult = sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 0;

        IF @LockResult < 0
        BEGIN
            RAISERROR('This drop-ship checkout is already being processed.', 16, 1);
        END

        -- ============================================================
        -- SALES SIDE
        -- ============================================================

        IF @IsEdit = 0
        BEGIN
            -- First save: create new Sales header
            SET @SalesNumber = NEXT VALUE FOR dbo.Seq_SalesNumber;

            EXEC dbo.SalesDocNumber_Generate
                @DocType = 'SO',
                @SalesDocNumber = @SalesDocNumber OUTPUT;

            INSERT INTO [dbo].[Sales]
            (
                [SalesNumber], [StageId], [SalesDate], [ShipDate], [ShipRoute],
                [ShipId], [BillId], [SalesRepId], [TermId],
                [SubTotal], [TaxableTotal], [TaxPercent], [TaxTotal], [SalesTotal], [AmountDue],
                [Instruction], [ShippingCarrierId], [IsLoadSeparate], [IsLocked],
                [IsStatementAttached], [Enterby], [CreatedAt],
                [DocType], [IsDropShip], [CustPONumber], [ParentSalesNumber], [SalesDocNumber]
            )
            VALUES
            (
                @SalesNumber, 0, @SalesDate, @ShipDate, @ShipRoute,
                @PayeeId, @BillId, @SalesRepId, @TermId,
                0, 0, @TaxRate, 0, 0, 0,
                @Instruction, @ShippingCarrierId, 0, 0,
                @IsStatementPrint, @EmpId, @SalesDate,
                'SO', 1, @CustPONumber, @ParentSalesNumber, @SalesDocNumber
            );

            SET @SalesId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            -- Edit mode: update existing Sales header
            UPDATE Sales SET
                ShipDate = @ShipDate,
                ShipRoute = @ShipRoute,
                Instruction = @Instruction,
                CustPONumber = COALESCE(@CustPONumber, CustPONumber),
                UpdatedAt = GETUTCDATE()
            WHERE SalesId = @SalesId;

            -- Replace SalesDetail from TempSales
            DELETE FROM SalesDetail WHERE SalesId = @SalesId;

            SET @SalesNumber = (SELECT SalesNumber FROM Sales WHERE SalesId = @SalesId);
        END

        INSERT INTO [dbo].[SalesDetail]
        (
            [SalesId], [LineId], [LineType], [ItemId], [AccountId],
            [ItemUnitId], [Unit], [OrdQty], [ShipQty], [BillQty],
            [UnitPrice], [ExtTotal], [Notes], [IsTaxable],
            [OrgPrice], [DiscountPercent], [FactorToBase],
            [CartLineType], [IsSystemManaged], [DisplaySort]
        )
        SELECT
            @SalesId, [LineId], [LineType], [ItemId], [AccountId],
            [ItemUnitId], [Unit], [OrdQty], [ShipQty], [BillQty],
            [UnitPrice],
            NULL,
            [Notes],
            CASE
                WHEN LineType = 'A' THEN 0
                ELSE (SELECT IsTaxable FROM dbo.Fn_IsItemTaxable(ItemId, @ShipDate, @PayeeId))
            END,
            [OrgPrice], [DiscountPercent], [FactorToBase],
            [CartLineType], [IsSystemManaged], [DisplaySort]
        FROM TempSales
        WHERE EmpId = @EmpId
          AND PayeeId = @PayeeId
          AND SalesId = CASE WHEN @IsEdit = 1 THEN @SalesId ELSE 0 END
          AND IsStrike = 0
        ORDER BY LineId;

        -- Calculate sales totals inline (same as Sales_Insert)
        SELECT @SubTotal = ISNULL(SUM(ROUND(ISNULL(BillQty, 0) * ISNULL(UnitPrice, 0), 2)), 0)
        FROM SalesDetail WHERE SalesId = @SalesId;

        SELECT @TaxableTotal = ISNULL(SUM(ROUND(ISNULL(BillQty, 0) * ISNULL(UnitPrice, 0), 2)), 0)
        FROM SalesDetail WHERE SalesId = @SalesId AND IsTaxable = 1;

        SET @TaxTotal = ROUND(@TaxableTotal * @TaxRate, 2);
        SET @SalesTotal = @SubTotal + @TaxTotal;

        UPDATE Sales SET
            SubTotal = @SubTotal,
            TaxableTotal = @TaxableTotal,
            TaxTotal = @TaxTotal,
            SalesTotal = @SalesTotal
        WHERE SalesId = @SalesId;

        -- ============================================================
        -- PURCHASE SIDE (linked PO)
        -- ============================================================

        -- Populate TempPurchase from SalesDetail (plan section 4 mapping)
        DELETE FROM TempPurchase WHERE EmpId = @EmpId AND PayeeId = @VendorPayeeId;

        INSERT INTO [TempPurchase]
            ([EmpId]
            ,[PayeeId]
            ,[PurchaseId]
            ,[LineId]
            ,[LineType]
            ,[ItemId]
            ,[AccountId]
            ,[ItemUnitId]
            ,[Unit]
            ,[Notes]
            ,[IsFree]
            ,[IsOut]
            ,[IsCRCG]
            ,[OrdQty0]
            ,[ShipQty]
            ,[BillQty]
            ,[OrdQty1]
            ,[ReceiveQty]
            ,[FinalQty]
            ,[BillPrice]
            ,[BillExtTotal]
            ,[FinalPrice]
            ,[ImportCommission]
            ,[FinalExtTotal]
            ,[FactorToBase]
            ,[ExpiryDate])
        SELECT
            @EmpId
            ,@VendorPayeeId
            ,CASE WHEN @IsEdit = 1 THEN @PurchaseId ELSE 0 END
            ,[LineId]
            ,[LineType]
            ,sd.[ItemId]
            ,[AccountId]
            ,sd.[ItemUnitId]
            ,sd.[Unit]
            ,[Notes]
            ,CASE WHEN (sd.BillQty = 0 AND sd.ShipQty != 0) THEN 1 ELSE 0 END
            ,CASE WHEN (sd.BillQty = 0 AND sd.ShipQty = 0) THEN 1 ELSE 0 END
            ,CASE WHEN (sd.BillQty != 0 AND sd.ShipQty = 0) THEN 1 ELSE 0 END
            ,sd.[OrdQty]
            ,NULL
            ,NULL
            ,sd.[OrdQty]
            ,NULL
            ,NULL
            ,ISNULL(i.RecentBaseCost, ISNULL(i.RecentCost, 0))
            ,NULL
            ,ISNULL(i.RecentBaseCost, ISNULL(i.RecentCost, 0))
            ,NULL
            ,NULL
            ,sd.[FactorToBase]
            ,NULL
        FROM SalesDetail sd
        LEFT JOIN ItemUnit i ON i.ItemUnitId = sd.ItemUnitId
        WHERE sd.SalesId = @SalesId
        -- 2026-07-13 DROPSHIP-ITEMONLY: item lines only; exclude account lines (LineType='A': customer shipping charge / GL). See plan-dropship-3-exclude-non-item.md
        AND sd.LineType = 'I'
        ORDER BY sd.LineId;

        -- 2026-07-13 DROPSHIP-ITEMONLY guard: after the item-only filter, an all-account-line SO yields 0 TempPurchase
        -- rows. Fail fast so we never create (or, in edit mode, replace with) an empty linked vendor PO.
        -- (RAISERROR sev 16 -> the CATCH below rolls back + re-THROWs, matching the applock check style.)
        IF NOT EXISTS (
            SELECT 1 FROM TempPurchase
            WHERE EmpId = @EmpId
              AND PayeeId = @VendorPayeeId
              AND PurchaseId = CASE WHEN @IsEdit = 1 THEN @PurchaseId ELSE 0 END
        )
            RAISERROR('This drop-ship order has no item lines to source from a vendor.', 16, 1);

        IF @IsEdit = 0
        BEGIN
            -- First save: create new Purchase header
            SET @PurchaseNumber = NEXT VALUE FOR dbo.Seq_PurchaseNumber;

            INSERT INTO [dbo].[Purchase]
                ([PurchaseNumber]
                ,[StageId]
                ,[PayeeId]
                ,[PurchaseDate]
                ,[EnterDate]
                -- 2026-07-14 DROPSHIP-ARRIVALDATE: old code omitted [ArrivalDate].
                ,[ArrivalDate]
                ,[TermId]
                ,[VendorTotal]
                ,[PurchaseTotal]
                ,[AmountDue]
                ,[PaymentApplied]
                ,[DiscountApplied]
                ,[IsLocked]
                ,[IsStartFromPO]
                ,[IsDropShip]
                ,[FactorPO]
                ,[DropShipSalesId]
                ,[CreatedAt])
            VALUES
                (@PurchaseNumber
                ,1
                ,@VendorPayeeId
                ,@PurchaseDate
                ,GETDATE()
                -- 2026-07-14 DROPSHIP-ARRIVALDATE: old code omitted this value, leaving Purchase.ArrivalDate NULL.
                ,@ShipDate
                ,@VendorTermId
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,1
                ,1
                ,@FactorPO
                ,@SalesId
                ,GETUTCDATE());

            SET @PurchaseId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            -- Edit mode: delete existing PurchaseDetail, will re-insert from TempPurchase
            DELETE FROM PurchaseDetail WHERE PurchaseId = @PurchaseId;

            -- 2026-07-14 DROPSHIP-ARRIVALDATE old code:
            -- UPDATE Purchase SET
            --     UpdatedAt = GETUTCDATE()
            -- WHERE PurchaseId = @PurchaseId;
            UPDATE Purchase SET
                -- 2026-07-14 DROPSHIP-ARRIVALDATE: keep existing linked PO arrival date in sync with selected ShipDate.
                ArrivalDate = @ShipDate,
                FactorPO = COALESCE(@FactorPO, FactorPO),
                UpdatedAt = GETUTCDATE()
            WHERE PurchaseId = @PurchaseId;

            SET @PurchaseNumber = (SELECT PurchaseNumber FROM Purchase WHERE PurchaseId = @PurchaseId);
        END

        -- Insert PurchaseDetail from TempPurchase
        INSERT INTO [dbo].[PurchaseDetail]
            ([PurchaseId]
            ,[LineId]
            ,[LineType]
            ,[ItemId]
            ,[AccountId]
            ,[ItemUnitId]
            ,[Unit]
            ,[Notes]
            ,[IsFree]
            ,[IsOut]
            ,[IsCRCG]
            ,[OrdQty0]
            ,[ShipQty]
            ,[BillQty]
            ,[OrdQty1]
            ,[ReceiveQty]
            ,[FinalQty]
            ,[BillPrice]
            ,[BillExtTotal]
            ,[FinalPrice]
            ,[ImportCommission]
            ,[FinalExtTotal]
            ,[FactorToBase]
            ,[ExpiryDate])
        SELECT
            @PurchaseId
            ,[LineId]
            ,[LineType]
            ,[ItemId]
            ,[AccountId]
            ,[ItemUnitId]
            ,[Unit]
            ,[Notes]
            ,[IsFree]
            ,[IsOut]
            ,[IsCRCG]
            ,[OrdQty0]
            ,[ShipQty]
            ,[BillQty]
            ,[OrdQty1]
            ,[ReceiveQty]
            ,[FinalQty]
            ,[BillPrice]
            ,[BillExtTotal]
            ,[FinalPrice]
            ,[ImportCommission]
            ,[FinalExtTotal]
            ,[FactorToBase]
            ,[ExpiryDate]
        FROM TempPurchase
        WHERE EmpId = @EmpId AND PayeeId = @VendorPayeeId
          AND PurchaseId = CASE WHEN @IsEdit = 1 THEN @PurchaseId ELSE 0 END
        ORDER BY LineId;

        -- Calculate purchase totals from PurchaseDetail
        SELECT
			@BillTotal = ISNULL(SUM(ROUND(BillQty * BillPrice, 2)), 0),
			@FinalTotal = ISNULL(SUM(ROUND(FinalQty * FinalPrice, 2)), 0)
		FROM PurchaseDetail
		WHERE PurchaseId = @PurchaseId;

        UPDATE Purchase SET
            VendorTotal = @BillTotal,
            PurchaseTotal = @FinalTotal
        WHERE PurchaseId = @PurchaseId;

        -- Set header linkage on Sales
        UPDATE Sales SET
            IsDropShip = 1,
            DropShipPurchaseId = @PurchaseId
        WHERE SalesId = @SalesId;

        -- Clean up temp rows
        DELETE FROM TempSales
        WHERE EmpId = @EmpId AND PayeeId = @PayeeId
          AND SalesId = CASE WHEN @IsEdit = 1 THEN @SalesId ELSE 0 END;

        DELETE FROM TempPurchase
        WHERE EmpId = @EmpId AND PayeeId = @VendorPayeeId;

        SET @NewSalesId = @SalesId;
        SET @NewPurchaseId = @PurchaseId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    -- Post-commit follow-up (non-core, outside transaction)
    EXEC [Sales_CalcTotal] @SalesId;

    EXEC [Purchase_CalcTotalAndPercent] @PurchaseId,@FinalTotal OUTPUT
END


