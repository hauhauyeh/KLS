
-- DropShipment_InsertSalesAndPO
-- Creates or updates a drop-ship sales order (StageId=0) and its linked
-- purchase PO (StageId=1) in one transaction. No journal entries are created.
--
-- First save: insert Sales + SalesDetail from TempSales, then copy lines to
-- TempPurchase and insert Purchase + PurchaseDetail.
-- Edit mode: update existing Sales/SalesDetail, then full-replace linked
-- PurchaseDetail from current SalesDetail via TempPurchase.

CREATE   PROCEDURE [dbo].[DropShipment_InsertSalesAndPO]
    @SalesId INT,
    @PayeeId INT,
    @VendorPayeeId INT,
    @ShipDate DATE,
    @ShipRoute NVARCHAR(10),
    @Instruction NVARCHAR(300) = 'Web',
    @EmpId INT,
    @PurchaseDate DATE = NULL,
    @NewSalesId INT OUTPUT,
    @NewPurchaseId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

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
    DECLARE @FinalTotal DECIMAL(18,2)

    SET @PurchaseDate = ISNULL(@PurchaseDate, CAST(GETDATE() AS DATE));

    IF @SalesId>0
        SELECT @VendorPayeeId = PayeeId 
        FROM Purchase WHERE PurchaseId = (SELECT DropShipPurchaseId FROM Sales WHERE SalesId = @SalesId)

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

            INSERT INTO [dbo].[Sales]
            (
                [SalesNumber], [StageId], [SalesDate], [ShipDate], [ShipRoute],
                [ShipId], [BillId], [SalesRepId], [TermId],
                [SubTotal], [TaxableTotal], [TaxPercent], [TaxTotal], [SalesTotal], [AmountDue],
                [Instruction], [ShippingCarrierId], [IsLoadSeparate], [IsLocked],
                [IsStatementAttached], [Enterby], [CreatedAt],
                [DocType], [IsDropShip]
            )
            VALUES
            (
                @SalesNumber, 0, @SalesDate, @ShipDate, @ShipRoute,
                @PayeeId, @BillId, @SalesRepId, @TermId,
                0, 0, @TaxRate, 0, 0, 0,
                @Instruction, @ShippingCarrierId, 0, 0,
                @IsStatementPrint, @EmpId, @SalesDate,
                'SO', 1
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
            ,ISNULL(i.RecentCost, 0)
            ,NULL
            ,ISNULL(i.RecentCost, 0)
            ,NULL
            ,NULL
            ,sd.[FactorToBase]
            ,NULL
        FROM SalesDetail sd
        LEFT JOIN ItemUnit i ON i.ItemUnitId = sd.ItemUnitId
        WHERE sd.SalesId = @SalesId
        ORDER BY sd.LineId;

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
                ,[TermId]
                ,[VendorTotal]
                ,[PurchaseTotal]
                ,[AmountDue]
                ,[PaymentApplied]
                ,[DiscountApplied]
                ,[IsLocked]
                ,[IsStartFromPO]
                ,[IsDropShip]
                ,[DropShipSalesId]
                ,[CreatedAt])
            VALUES
                (@PurchaseNumber
                ,1
                ,@VendorPayeeId
                ,@PurchaseDate
                ,GETDATE()
                ,@VendorTermId
                ,0
                ,0
                ,0
                ,0
                ,0
                ,0
                ,1
                ,1
                ,@SalesId
                ,GETUTCDATE());

            SET @PurchaseId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            -- Edit mode: delete existing PurchaseDetail, will re-insert from TempPurchase
            DELETE FROM PurchaseDetail WHERE PurchaseId = @PurchaseId;

            UPDATE Purchase SET
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

