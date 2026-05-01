-- Consolidated sales posting/order rollback bundle
-- Restores developer baseline captured before the 2026-04-15 sales posting refactor
-- Includes dbo.Sales_CalcTotal, dbo.Sales_Insert, dbo.Sales_PartialUpdate,
-- dbo.Sales_Inject, and dbo.TRG_Update_TempSalesReSeq
-- Rebuilt: 2026-04-16

-- Consolidated sales posting rollback bundle
-- Restores developer baseline captured before 2026-04-15 posting refactor
-- Use this to roll back the full consolidated sales posting change set

-- Rollback bundle: restore live Sales posting procedures
-- Baseline captured: 2026-04-15 before deployment
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Sales_CalcTotal]

	@SalesId INT,
	@SalesTotal DECIMAL(18,2) OUTPUT
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @SubTotal DECIMAL(18,2)
	DECLARE @TaxableTotal DECIMAL(18,2)
	DECLARE @TaxTotal DECIMAL(18,2)
	DECLARE @TaxPercent DECIMAL(18,4)
	DECLARE @AmountDue DECIMAL(18,2)
	DECLARE @PaymentApplied DECIMAL(18,2);
	DECLARE @DiscountApplied DECIMAL(18,2);

	DECLARE @StageId INT
	DECLARE @ShipDate DATE
	DECLARE @PayeeId INT
	DECLARE @TermId INT;
	DECLARE @DueDate DATE;
	DECLARE @DiscDate DATE
	DECLARE @DiscRate DECIMAL(18,4)

	DECLARE @Aging INT=0;
	DECLARE @InvoiceAging INT=0;
	
	SELECT @StageId=StageId,
	@TaxPercent=TaxPercent,
	@ShipDate=ShipDate,
	@PayeeId=ShipId
	FROM Sales WHERE SalesId=@SalesId

	SELECT @SubTotal = ISNULL(SUM(ROUND(BillQty*UnitPrice,2)),0)
	FROM SalesDetail WHERE SalesId=@SalesId

	SELECT @TaxableTotal = ISNULL(ROUND(SUM(BillQty*UnitPrice),2),0) 
	FROM SalesDetail WHERE SalesId=@SalesId AND IsTaxable=1

	SET @TaxTotal = ROUND(@TaxableTotal * @TaxPercent,2)
	SET @SalesTotal = @SubTotal + @TaxTotal

	SELECT 
	  @PaymentApplied = ISNULL(SUM(PaymentApplied), 0),
	  @DiscountApplied = ISNULL(SUM(DiscountApplied), 0)
	FROM CustomerPaymentDetail
	WHERE SalesId = @SalesId;

	IF (@PaymentApplied!=0 OR @DiscountApplied!=0)
		SET @AmountDue=@SalesTotal-(@PaymentApplied+@DiscountApplied)
	ELSE
		SET @AmountDue=@SalesTotal

	--Calculate DueDate from ShipDate and Term
	EXEC Fn_Calc_DueDate @ShipDate,@TermId,@DueDate OUTPUT,@DiscDate OUTPUT,@DiscRate OUTPUT

	--Calculate Aging
	EXEC Fn_Calc_Aging @ShipDate,@PayeeId,@AmountDue,@Aging OUTPUT,@InvoiceAging OUTPUT

	UPDATE Sales SET
		SubTotal=@SubTotal,
		TaxTotal=@TaxTotal,
		TaxableTotal=@TaxableTotal,
		SalesTotal=@SalesTotal,
		AmountDue=@AmountDue,
		DueDate=@DueDate,
		Aging=@Aging,
		InvoiceAging=@InvoiceAging,
		DiscountDate=@DiscDate,
		DiscountPercent=@DiscRate,
		PaymentApplied=@PaymentApplied,
		DiscountApplied=@DiscountApplied
		--UpdatedAt=GETUTCDATE()
	WHERE SalesId=@SalesId

	EXEC [Payee_UpdateAging] @PayeeId,1

	-- Calculate Base Qty
	;WITH cte AS
	(
		SELECT *,
			   ROW_NUMBER() OVER (ORDER BY LineId) AS NewLineId
		FROM SalesDetail
		WHERE SalesId = @SalesId
	)
	UPDATE cte
	SET 
		LineId = NewLineId,
		BaseOrdQty  = ROUND(OrdQty  / FactorToBase, 6),
		BaseShipQty = ROUND(ShipQty / FactorToBase, 6),
		BaseBillQty = ROUND(BillQty / FactorToBase, 6);

	UPDATE Customer SET LastCallingStatus='Yes--' + CONVERT(nvarchar,@SubTotal) WHERE PayeeId=@PayeeId

	IF @StageId=0 
		EXEC [FIFO_Single_Allocation_OrderStage] @SalesId

	IF @StageId>=2 
		EXEC [FIFO_Single_Allocation] @SalesId

	EXEC [Sales_CalcMargin] @SalesId
END



GO


GO


CREATE PROCEDURE [dbo].[Sales_Insert]
    @SalesId INT,
    @PayeeId INT,
    @ShipDate DATE,
    @ShipRoute NVARCHAR(10),
    @Instruction NVARCHAR(300) = 'Web',
    @StageId INT,
    @EmpId INT,
    @NewSalesId INT OUTPUT,
    @DocType CHAR(2) = 'SO',
    @ParentSalesNumber INT = NULL,
    @AllowNoParentOverride BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TermId INT;
    DECLARE @SalesNumber INT;
    DECLARE @SalesDate DATETIME = GETUTCDATE();
    DECLARE @BillId INT;
    DECLARE @TaxRate DECIMAL(18,4);
    DECLARE @RCExpireDate DATE;
    DECLARE @SalesRepId INT;
    DECLARE @IsCreditHold BIT;
    DECLARE @IsStatementPrint BIT;
    DECLARE @ShippingCarrierId INT;
    DECLARE @SalesTotal DECIMAL(18,2);
    DECLARE @TaxTotal DECIMAL(18,2);

    DECLARE @TxId BIGINT;
    DECLARE @CrDeAmount DECIMAL(18,2) = 0;
    DECLARE @AccountId INT;
    DECLARE @AccountCode NVARCHAR(50);

    DECLARE @DocOrder INT;
    DECLARE @JournalDocType NVARCHAR(100);

    IF @DocType = 'SO'
    BEGIN
        SET @ParentSalesNumber = NULL;
        SET @JournalDocType = 'Sales';
    END
    ELSE IF @DocType = 'CM'
    BEGIN
        SET @JournalDocType = 'Sales Credit Memo';

        IF @ParentSalesNumber IS NULL AND ISNULL(@AllowNoParentOverride, 0) = 0
        BEGIN
            RAISERROR('Credit memo without parent requires manager override.', 16, 1);
            RETURN;
        END

        IF EXISTS
        (
            SELECT 1
            FROM TempSales
            WHERE EmpId = @EmpId
              AND PayeeId = @PayeeId
              AND SalesId = 0
              AND IsStrike = 0
              AND (
                    (@ParentSalesNumber IS NULL AND ParentSalesNumber IS NULL)
                    OR (ParentSalesNumber = @ParentSalesNumber)
                  )
              AND ISNULL(ExtTotal, ISNULL(OrdQty, 0) * ISNULL(UnitPrice, 0)) >= 0
        )
        BEGIN
            RAISERROR('Credit memo lines must have negative totals.', 16, 1);
            RETURN;
        END

        IF EXISTS
        (
            SELECT 1
            FROM TempSales
            WHERE EmpId = @EmpId
              AND PayeeId = @PayeeId
              AND SalesId = 0
              AND IsStrike = 0
              AND (
                    (@ParentSalesNumber IS NULL AND ParentSalesNumber IS NULL)
                    OR (ParentSalesNumber = @ParentSalesNumber)
                  )
              AND LineType <> 'I'
        )
        BEGIN
            RAISERROR('Credit memo only supports item lines.', 16, 1);
            RETURN;
        END
    END
    ELSE IF @DocType = 'DM'
    BEGIN
        SET @JournalDocType = 'Sales Debit Memo';
    END
    ELSE
    BEGIN
        RAISERROR('Invalid document type.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS
    (
        SELECT 1
        FROM TempSales
        WHERE EmpId = @EmpId
          AND PayeeId = @PayeeId
          AND SalesId = 0
          AND IsStrike = 0
          AND (
                (@DocType = 'SO')
                OR (@ParentSalesNumber IS NULL AND ParentSalesNumber IS NULL)
                OR (ParentSalesNumber = @ParentSalesNumber)
              )
    )
    BEGIN
        RAISERROR('No temp sales rows found for this checkout group.', 16, 1);
        RETURN;
    END

    EXEC [Get_SourceDocOrder] @JournalDocType, @DocOrder OUTPUT;

    DECLARE @AcctTable AS TABLE
    (
        Id INT IDENTITY(1,1),
        AccountCode NVARCHAR(50),
        AccountId INT
    );

    INSERT INTO @AcctTable (AccountCode) VALUES ('@AR');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@FSTP');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@ICREDIT');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@ISALE');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@COGS');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@INV');

    UPDATE t
    SET t.AccountId = a.AccountId
    FROM @AcctTable AS t
    INNER JOIN Account AS a ON t.AccountCode = a.AccountCode;

    SELECT
        @TermId = TermId,
        @BillId = ISNULL(BillId, p.PayeeId),
        @TaxRate = TaxRate,
        @RCExpireDate = RCExpireDate,
        @SalesRepId = ISNULL(SalesRepId, @EmpId),
        @IsCreditHold = IsCreditHold,
        @ShippingCarrierId = ShippingCarrierId,
        @IsStatementPrint = IsStatementPrint
    FROM Payee AS p
    INNER JOIN Customer AS c ON p.PayeeId = c.PayeeId
    WHERE p.PayeeId = @PayeeId;

    IF @SalesId > 0
        SET @SalesNumber = @SalesId;
    ELSE
        SET @SalesNumber = NEXT VALUE FOR dbo.Seq_SalesNumber;

    IF @ShipDate IS NULL
        EXEC dbo.Fn_Calc_NextShipDate @PayeeId, @ShipDate OUTPUT;

    IF @ShipRoute = 'CM'
        EXEC [Get_TodayLocalDate] @ShipDate OUTPUT;

    INSERT INTO [dbo].[Sales]
    (
        [SalesNumber],
        [StageId],
        [SalesDate],
        [ShipDate],
        [ShipRoute],
        [ShipId],
        [BillId],
        [SalesRepId],
        [TermId],
        [SubTotal],
        [TaxableTotal],
        [TaxPercent],
        [TaxTotal],
        [SalesTotal],
        [AmountDue],
        [Instruction],
        [ShippingCarrierId],
        [IsLoadSeparate],
        [IsLocked],
        [IsStatementAttached],
        [Enterby],
        [CreatedAt],
        [ParentSalesNumber],
        [DocType]
    )
    VALUES
    (
        @SalesNumber,
        @StageId,
        @SalesDate,
        @ShipDate,
        @ShipRoute,
        @PayeeId,
        @BillId,
        @SalesRepId,
        @TermId,
        0,
        0,
        @TaxRate,
        0,
        0,
        0,
        @Instruction,
        @ShippingCarrierId,
        0,
        0,
        @IsStatementPrint,
        @EmpId,
        @SalesDate,
        @ParentSalesNumber,
        @DocType
    );

    SELECT @SalesId = SCOPE_IDENTITY();

    -- Phase 2E: Use MERGE to capture TempSalesId Ã¢â€ â€™ SalesDetailId mapping
    DECLARE @IdMap TABLE
    (
        TempSalesId INT,
        SalesDetailId INT,
        ParentTempSalesId INT,
        RootTempSalesId INT
    );

    MERGE INTO [dbo].[SalesDetail] AS target
    USING
    (
        SELECT
            TempSalesId,
            ParentTempSalesId,
            RootTempSalesId,
            LineId,
            LineType,
            ItemId,
            AccountId,
            ItemUnitId,
            Unit,
            OrdQty,
            ShipQty,
            BillQty,
            UnitPrice,
            ISNULL(ExtTotal, ISNULL(OrdQty, 0) * ISNULL(UnitPrice, 0)) AS ExtTotal,
            Notes,
            CASE
                WHEN LineType = 'A' THEN 0
                ELSE (SELECT IsTaxable FROM dbo.Fn_IsItemTaxable(ItemId, @ShipDate, @PayeeId))
            END AS IsTaxable,
            OrgPrice,
            DiscountPercent,
            FactorToBase,
            CartLineType,
            IsSystemManaged,
            DisplaySort
        FROM TempSales
        WHERE EmpId = @EmpId
          AND PayeeId = @PayeeId
          AND SalesId = 0
          AND IsStrike = 0
          AND (
                (@DocType = 'SO')
                OR (@ParentSalesNumber IS NULL AND ParentSalesNumber IS NULL)
                OR (ParentSalesNumber = @ParentSalesNumber)
              )
    ) AS source
    ON 1 = 0
    WHEN NOT MATCHED THEN
        INSERT
        (
            [SalesId],
            [LineId],
            [LineType],
            [ItemId],
            [AccountId],
            [ItemUnitId],
            [Unit],
            [OrdQty],
            [ShipQty],
            [BillQty],
            [UnitPrice],
            [ExtTotal],
            [Notes],
            [IsTaxable],
            [OrgPrice],
            [DiscountPercent],
            [FactorToBase],
            [ParentSalesDetailId],
            [RootSalesDetailId],
            [CartLineType],
            [IsSystemManaged],
            [DisplaySort]
        )
        VALUES
        (
            @SalesId,
            source.LineId,
            source.LineType,
            source.ItemId,
            source.AccountId,
            source.ItemUnitId,
            source.Unit,
            source.OrdQty,
            source.ShipQty,
            source.BillQty,
            source.UnitPrice,
            source.ExtTotal,
            source.Notes,
            source.IsTaxable,
            source.OrgPrice,
            source.DiscountPercent,
            source.FactorToBase,
            NULL,
            NULL,
            source.CartLineType,
            source.IsSystemManaged,
            source.DisplaySort
        )
    OUTPUT
        source.TempSalesId,
        inserted.SalesDetailId,
        source.ParentTempSalesId,
        source.RootTempSalesId
    INTO @IdMap
    (
        TempSalesId,
        SalesDetailId,
        ParentTempSalesId,
        RootTempSalesId
    );

    -- Phase 2E: Update parent/root references using the mapping
    UPDATE sd
    SET
        sd.ParentSalesDetailId = pmap.SalesDetailId,
        sd.RootSalesDetailId = ISNULL(rmap.SalesDetailId, pmap.SalesDetailId)
    FROM SalesDetail sd
    INNER JOIN @IdMap m ON m.SalesDetailId = sd.SalesDetailId
    LEFT JOIN @IdMap pmap ON pmap.TempSalesId = m.ParentTempSalesId
    LEFT JOIN @IdMap rmap ON rmap.TempSalesId = m.RootTempSalesId
    WHERE m.ParentTempSalesId IS NOT NULL;

    EXEC [Sales_CalcTotal] @SalesId, @SalesTotal OUTPUT;

    SELECT @TaxTotal = TaxTotal
    FROM Sales
    WHERE SalesId = @SalesId;

    ------- END OF SOURCE TABLE (Sales, SalesDetail, Payee) ---------

    CREATE TABLE #SalTxDetail
    (
        TxDetailId INT IDENTITY(1,1),
        TxId BIGINT,
        AccountId INT,
        PayeeId INT,
        ItemId INT,
        Qty DECIMAL(18,6),
        Price DECIMAL(18,6),
        BillQty DECIMAL(18,6),
        FactorToBase DECIMAL(18,6),
        Amount DECIMAL(18,2),
        CrDeAmount DECIMAL(18,2),
        SrcDetailId INT,
        InventoryQty DECIMAL(18,6)
    );

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
        @ShipDate,
        GETUTCDATE(),
        @DocOrder,
        @JournalDocType,
        @SalesNumber
    );

    SELECT @TxId = SCOPE_IDENTITY();

    SELECT @AccountId = AccountId
    FROM @AcctTable
    WHERE AccountCode = '@AR';

    EXEC Fn_Adjust_CrDeAmount @AccountId, @SalesTotal, @CrDeAmount OUTPUT;

    INSERT INTO #SalTxDetail
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
        @SalesTotal,
        @CrDeAmount
    );

    IF @TaxTotal <> 0
    BEGIN
        SELECT @AccountId = AccountId
        FROM @AcctTable
        WHERE AccountCode = '@FSTP';

        EXEC Fn_Adjust_CrDeAmount @AccountId, @TaxTotal, @CrDeAmount OUTPUT;

        INSERT INTO #SalTxDetail
        (
            [TxId],
            [AccountId],
            [Amount],
            [CrDeAmount]
        )
        VALUES
        (
            @TxId,
            @AccountId,
            @TaxTotal,
            @CrDeAmount
        );
    END

    --- for multiple Items ---
    DECLARE @LineType NVARCHAR(1);
    DECLARE @ItemId INT;
    DECLARE @ItemAccountId INT;
    DECLARE @ItemType NVARCHAR(50);
    DECLARE @OrdQty DECIMAL(18,2);
    DECLARE @ShipQty DECIMAL(18,2);
    DECLARE @BillQty DECIMAL(18,2);
    DECLARE @UnitPrice DECIMAL(18,2);
    DECLARE @BaseShipQty DECIMAL(18,6);
    DECLARE @BaseBillQty DECIMAL(18,6);
    DECLARE @FactorToBase DECIMAL(18,6);
    DECLARE @SDId INT;

    DECLARE @ExtTotal DECIMAL(18,2);

    DECLARE @ItmTable TABLE
    (
        [AutoId] INT IDENTITY(1,1) NOT NULL,
        [LineType] NVARCHAR(1),
        [ItemId] INT NULL,
        [AccountId] INT NULL,
        [ItemType] NVARCHAR(50) NULL,
        [OrdQty] DECIMAL(18,2) NULL,
        [ShipQty] DECIMAL(18,2) NULL,
        [BillQty] DECIMAL(18,2) NULL,
        [UnitPrice] DECIMAL(18,2) NULL,
        [BaseShipQty] DECIMAL(18,6) NULL,
        [BaseBillQty] DECIMAL(18,6) NULL,
        [FactorToBase] DECIMAL(18,6),
        [SDId] INT
    );

    INSERT INTO @ItmTable
    SELECT
        sd.LineType,
        sd.ItemId,
        sd.AccountId,
        i.ItemType,
        OrdQty,
        ShipQty,
        BillQty,
        UnitPrice,
        sd.BaseShipQty,
        sd.BaseBillQty,
        sd.FactorToBase,
        SalesDetailId
    FROM SalesDetail AS sd
    LEFT JOIN Item AS i ON sd.ItemId = i.ItemId
    WHERE SalesId = @SalesId
    ORDER BY SalesDetailId;

    DECLARE @RowNum INT = 1;
    DECLARE @MaxRow INT;

    SELECT @MaxRow = COUNT(AutoId)
    FROM @ItmTable;

    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT
            @LineType = LineType,
            @ItemId = ItemId,
            @ItemAccountId = AccountId,
            @ItemType = ItemType,
            @OrdQty = OrdQty,
            @ShipQty = ShipQty,
            @BillQty = BillQty,
            @UnitPrice = UnitPrice,
            @BaseShipQty = BaseShipQty,
            @BaseBillQty = BaseBillQty,
            @FactorToBase = FactorToBase,
            @SDId = SDId
        FROM @ItmTable
        WHERE AutoId = @RowNum;

        SET @ExtTotal = ROUND(@BillQty * @UnitPrice, 2);

        -- If It's Account Code
        IF @LineType = 'A'
        BEGIN
            EXEC Fn_Adjust_CrDeAmount @ItemAccountId, @ExtTotal, @CrDeAmount OUTPUT;

            INSERT INTO #SalTxDetail
            (
                [TxId],
                [AccountId],
                [PayeeId],
                [Qty],
                [Price],
                [BillQty],
                [Amount],
                [CrDeAmount],
                [SrcDetailId]
            )
            VALUES
            (
                @TxId,
                @ItemAccountId,
                @PayeeId,
                @BillQty,
                @UnitPrice,
                @ExtTotal,
                @ExtTotal,
                @CrDeAmount,
                @SDId
            );
        END
        ELSE
        BEGIN
            --For NonInventory Logic
            IF @ExtTotal < 0
                SET @AccountCode = '@ICREDIT';
            ELSE
                SET @AccountCode = '@ISALE';

            SELECT @AccountId = AccountId
            FROM @AcctTable
            WHERE AccountCode = @AccountCode;

            EXEC Fn_Adjust_CrDeAmount @AccountId, @ExtTotal, @CrDeAmount OUTPUT;

            IF @ItemType = 'NonInventory'
            BEGIN
                INSERT INTO #SalTxDetail
                (
                    [TxId],
                    [AccountId],
                    [PayeeId],
                    [ItemId],
                    [Qty],
                    [Price],
                    [BillQty],
                    [Amount],
                    [CrDeAmount],
                    [SrcDetailId],
                    [InventoryQty]
                )
                VALUES
                (
                    @TxId,
                    @AccountId,
                    @PayeeId,
                    @ItemId,
                    @BillQty,
                    @UnitPrice,
                    @ExtTotal,
                    @ExtTotal,
                    @CrDeAmount,
                    @SDId,
                    @BillQty * -1
                );
            END
            ELSE
            BEGIN
                --If it's Inventory (ISALES, COGS, INV Account)
                INSERT INTO #SalTxDetail
                (
                    [TxId],
                    [AccountId],
                    [PayeeId],
                    [ItemId],
                    [Qty],
                    [Price],
                    [BillQty],
                    [Amount],
                    [CrDeAmount],
                    [SrcDetailId],
                    [FactorToBase],
                    [InventoryQty]
                )
                VALUES
                (
                    @TxId,
                    @AccountId,
                    @PayeeId,
                    @ItemId,
                    @BillQty,
                    @UnitPrice,
                    @ExtTotal,
                    @ExtTotal,
                    @CrDeAmount,
                    @SDId,
                    @FactorToBase,
                    @BillQty * -1
                );

                --For COST OF GOOD SOLD account
                SELECT @AccountId = AccountId
                FROM @AcctTable
                WHERE AccountCode = '@COGS';

                INSERT INTO #SalTxDetail
                (
                    [TxId],
                    [AccountId],
                    [PayeeId],
                    [ItemId],
                    [FactorToBase],
                    [SrcDetailId]
                )
                VALUES
                (
                    @TxId,
                    @AccountId,
                    @PayeeId,
                    @ItemId,
                    @FactorToBase,
                    @SDId
                );

                --For Inventory account
                SELECT @AccountId = AccountId
                FROM @AcctTable
                WHERE AccountCode = '@INV';

                INSERT INTO #SalTxDetail
                (
                    [TxId],
                    [AccountId],
                    [PayeeId],
                    [ItemId],
                    [Qty],
                    [Price],
                    [BillQty],
                    [SrcDetailId],
                    [FactorToBase],
                    [InventoryQty]
                )
                VALUES
                (
                    @TxId,
                    @AccountId,
                    @PayeeId,
                    @ItemId,
                    @BaseShipQty,
                    @UnitPrice,
                    @BaseBillQty,
                    @SDId,
                    @FactorToBase,
                    @BaseBillQty * -1
                );
            END
        END

        SET @RowNum += 1;
    END

    INSERT INTO TransactionJournalDetail
    (
        [TxId],
        [AccountId],
        [PayeeId],
        [ItemId],
        [Qty],
        [Price],
        [BillQty],
        [Amount],
        [CrDeAmount],
        [SourceDetailId],
        [FactorToBase],
        [InventoryQty]
    )
    SELECT
        [TxId],
        [AccountId],
        [PayeeId],
        [ItemId],
        [Qty],
        [Price],
        [BillQty],
        [Amount],
        [CrDeAmount],
        [SrcDetailId],
        [FactorToBase],
        [InventoryQty]
    FROM #SalTxDetail
    ORDER BY TxDetailId;

    -- Phase 2E: Cleanup TempSalesPromo links before deleting TempSales (FK constraint)
    DELETE tsp
    FROM TempSalesPromo tsp
    WHERE EXISTS
    (
        SELECT 1
        FROM @IdMap m
        WHERE m.TempSalesId = tsp.OwnerTempSalesId
           OR m.TempSalesId = tsp.PromoTempSalesId
    );

    DELETE ts
    FROM TempSales ts
    INNER JOIN @IdMap m ON m.TempSalesId = ts.TempSalesId;

    SET @NewSalesId = @SalesId;

    EXEC Recalc_AfterInsert @TxId, @ShipDate;
END

GO




GO


CREATE PROCEDURE [dbo].[Sales_PartialUpdate]
	@SalesId INT,
	@EmpId INT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @TxId BIGINT
	DECLARE @SalesNumber INT
	DECLARE @DocType CHAR(2)
	DECLARE @JournalDocType NVARCHAR(100)
	DECLARE @ShipDate DATE
	DECLARE @IsLocked BIT
	DECLARE @PayeeId INT
	DECLARE @RowNum INT=1
	DECLARE @MaxRow INT
    DECLARE @CrDeAmount DECIMAL(18, 2)
    DECLARE @AccountCode NVARCHAR(50)
	DECLARE @OldItemId INT

	SELECT @SalesNumber=SalesNumber,@DocType=DocType,@ShipDate=ShipDate,@IsLocked=IsLocked,@PayeeId=ShipId
	FROM Sales WHERE SalesId=@SalesId

	SET @JournalDocType = CASE
		WHEN @DocType='CM' THEN 'Sales Credit Memo'
		WHEN @DocType='DM' THEN 'Sales Debit Memo'
		ELSE 'Sales'
	END

	SELECT @TxId=TxId FROM TransactionJournal
	WHERE SourceDocNumber=@SalesNumber AND SourceDocType=@JournalDocType

	DECLARE
        @LineId INT,
        @LineType NVARCHAR(1),
        @ItemId INT,
        @AccountId INT,
		@ItemUnitId INT,
        @Unit NVARCHAR(50),
		@BaseShipQty DECIMAL(18, 6),
		@BaseBillQty DECIMAL(18, 6),
        @OrdQty DECIMAL(18, 2),
        @ShipQty DECIMAL(18, 2),
        @BillQty DECIMAL(18, 2),
        @UnitPrice DECIMAL(18, 2),
        @ExtTotal DECIMAL(18, 2),
        @Notes NVARCHAR(300),
        @IsTaxable BIT,
        @OrgPrice DECIMAL(18, 2),
        @DiscountPercent DECIMAL(18, 4),
        @FactorToBase DECIMAL(18, 6),
        @ChangeStatus NVARCHAR(1),
        @SalesDetailId INT,
        @ItemType NVARCHAR(100),
        @CartLineType NVARCHAR(30),
        @IsSystemManaged BIT,
        @DisplaySort INT,
        @TempSalesId_Current INT;

	DECLARE @IdMap TABLE (
		TempSalesId INT,
		SalesDetailId INT
	);

	DECLARE @AcctTable AS Table(
		Id INT IDENTITY(1,1),
		AccountCode NVARCHAR(50),
		AccountId INT
	)

	INSERT INTO @AcctTable(AccountCode) VALUES('@AR')
    INSERT INTO @AcctTable(AccountCode) VALUES('@FSTP')
	INSERT INTO @AcctTable(AccountCode) VALUES('@ICREDIT')
    INSERT INTO @AcctTable(AccountCode) VALUES('@ISALE')
    INSERT INTO @AcctTable(AccountCode) VALUES('@COGS')
	INSERT INTO @AcctTable(AccountCode) VALUES('@INV')

	UPDATE t SET t.AccountId=a.AccountId
	FROM @AcctTable AS t INNER JOIN Account AS a ON t.AccountCode=a.AccountCode

	DECLARE @TempSaleTable TABLE (
		[AutoId] [int] IDENTITY(1,1) NOT NULL,
		[LineId] [int] NULL,
		[LineType] [nvarchar](1) NOT NULL,
		[ItemId] [int] NULL,
		[AccountId] [int] NULL,
		[ItemUnitId] [int] NULL,
		[Unit] [nvarchar](50) NULL,
		[OrdQty] [decimal](18, 2) NULL,
		[ShipQty] [decimal](18, 2) NULL,
		[BillQty] [decimal](18, 2) NULL,
		[UnitPrice] [decimal](18, 2) NULL,
		[ExtTotal] [decimal](18, 2) NULL,
		[Notes] [nvarchar](300) NULL,
		[IsTaxable] [bit] NOT NULL,
		[OrgPrice] [decimal](18, 2) NULL,
		[DiscountPercent] [decimal](18, 4) NULL,
		[FactorToBase] [decimal](18, 6) NULL,
		[ChangeStatus] [nvarchar](1) null,
		[SalesDetailId] [int] null,
		[ItemType] [nvarchar](100) NULL,
		[CartLineType] [nvarchar](30) NOT NULL,
		[IsSystemManaged] [bit] NOT NULL,
		[DisplaySort] [int] NULL,
		[TempSalesId] [int] NULL,
		[ParentTempSalesId] [int] NULL,
		[RootTempSalesId] [int] NULL
	)

	INSERT INTO @TempSaleTable
		([LineId],[LineType],[ItemId],[AccountId],[ItemUnitId],[Unit],
		 [OrdQty],[ShipQty],[BillQty],[UnitPrice],[ExtTotal],[Notes],
		 [IsTaxable],[OrgPrice],[DiscountPercent],[FactorToBase],
		 [ChangeStatus],[SalesDetailId],[ItemType],
		 [CartLineType],[IsSystemManaged],[DisplaySort],
		 [TempSalesId],[ParentTempSalesId],[RootTempSalesId])
	SELECT [LineId]
      ,[LineType]
      ,t.[ItemId]
      ,[AccountId]
	  ,[ItemUnitId]
      ,[Unit]
      ,[OrdQty]
      ,[ShipQty]
      ,[BillQty]
      ,[UnitPrice]
      ,[ExtTotal]
      ,[Notes]
      ,CASE
		WHEN LineType='A' THEN 0
		ELSE
		(Select IsTaxable FROM dbo.Fn_IsItemTaxable(t.ItemId,@ShipDate,@PayeeId))
	   END
      ,[OrgPrice]
      ,[DiscountPercent]
      ,[FactorToBase]
      ,[ChangeStatus]
      ,[SalesDetailId]
      ,i.ItemType
      ,[CartLineType]
      ,[IsSystemManaged]
      ,[DisplaySort]
      ,t.[TempSalesId]
      ,t.[ParentTempSalesId]
      ,t.[RootTempSalesId]
	FROM TempSales AS t LEFT JOIN Item AS i ON t.ItemId=i.ItemId
	WHERE EmpId=@EmpId AND PayeeId=@PayeeId AND SalesId=@SalesId AND ChangeStatus IS NOT NULL

	SELECT @MaxRow=COUNT(AutoId) FROM @TempSaleTable

	WHILE @RowNum <= @MaxRow
	BEGIN
		SELECT
            @LineId          = LineId,
            @LineType        = LineType,
            @ItemId          = ItemId,
            @AccountId       = AccountId,
			@ItemUnitId      = ItemUnitId,
            @Unit            = Unit,
			@BaseShipQty     = ROUND(ShipQty / FactorToBase, 6),
			@BaseBillQty     = ROUND(BillQty / FactorToBase, 6),
            @OrdQty          = OrdQty,
            @ShipQty         = ShipQty,
            @BillQty         = BillQty,
            @UnitPrice       = UnitPrice,
            @ExtTotal        = ExtTotal,
            @Notes           = Notes,
            @IsTaxable       = IsTaxable,
            @OrgPrice        = OrgPrice,
            @DiscountPercent = DiscountPercent,
            @FactorToBase    = FactorToBase,
            @ChangeStatus    = ChangeStatus,
            @SalesDetailId   = SalesDetailId,
            @ItemType        = ItemType,
            @CartLineType    = CartLineType,
            @IsSystemManaged = IsSystemManaged,
            @DisplaySort     = DisplaySort,
            @TempSalesId_Current = TempSalesId
        FROM @TempSaleTable
        WHERE AutoId = @RowNum;

        IF @ChangeStatus = 'I'
        BEGIN
			SET @ExtTotal= ROUND(@BillQty*@UnitPrice,2)

            INSERT INTO [dbo].[SalesDetail]
               ([SalesId]
               ,[LineId]
               ,[LineType]
               ,[ItemId]
               ,[AccountId]
			   ,[ItemUnitId]
               ,[Unit]
               ,[OrdQty]
               ,[ShipQty]
               ,[BillQty]
               ,[UnitPrice]
               ,[ExtTotal]
               ,[Notes]
               ,[IsTaxable]
               ,[OrgPrice]
               ,[DiscountPercent]
               ,[FactorToBase]
               ,[ParentSalesDetailId]
               ,[RootSalesDetailId]
               ,[CartLineType]
               ,[IsSystemManaged]
               ,[DisplaySort])
            VALUES
               (@SalesId,
                @LineId,
                @LineType,
                @ItemId,
                @AccountId,
				@ItemUnitId,
                @Unit,
                @OrdQty,
                @ShipQty,
                @BillQty,
                @UnitPrice,
                @ExtTotal,
                @Notes,
                @IsTaxable,
                @OrgPrice,
                @DiscountPercent,
                @FactorToBase,
                NULL,  -- ParentSalesDetailId (ID translation deferred)
                NULL,  -- RootSalesDetailId (ID translation deferred)
                @CartLineType,
                @IsSystemManaged,
                @DisplaySort)

            SET @SalesDetailId=SCOPE_IDENTITY();

            INSERT INTO @IdMap (TempSalesId, SalesDetailId) VALUES (@TempSalesId_Current, @SalesDetailId);

            -- If It's Account Code
            IF @LineType='A'
		    BEGIN
                EXEC Fn_Adjust_CrDeAmount @AccountId,@ExtTotal,@CrDeAmount OUTPUT

                INSERT INTO TransactionJournalDetail
					    ([TxId]
					    ,[AccountId]
					    ,[PayeeId]
					    ,[Qty]
					    ,[Price]
					    ,[BillQty]
					    ,[Amount]
					    ,[CrDeAmount]
					    ,[SourceDetailId])
				    VALUES
					    (@TxId
					    ,@AccountId
					    ,@PayeeId
					    ,@BillQty
					    ,@UnitPrice
					    ,@ExtTotal
					    ,@ExtTotal -- amount
					    ,@CrDeAmount
					    ,@SalesDetailId)
            END
            ELSE
            BEGIN
                --For NonInventory Logic
                IF @ExtTotal<0
				    SET @AccountCode = '@ICREDIT'
			    ELSE
				    SET @AccountCode = '@ISALE'

                SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode=@AccountCode
                EXEC Fn_Adjust_CrDeAmount @AccountId,@ExtTotal,@CrDeAmount OUTPUT

                IF @ItemType = 'NonInventory'
                BEGIN
                    INSERT INTO TransactionJournalDetail
						([TxId]
						,[AccountId]
						,[PayeeId]
						,[ItemId]
                        ,[Qty]
						,[Price]
						,[BillQty]
						,[Amount]
						,[CrDeAmount]
						,[SourceDetailId]
						,[InventoryQty])
				    VALUES
						(@TxId
						,@AccountId
						,@PayeeId
						,@ItemId
                        ,@BillQty
					    ,@UnitPrice
					    ,@ExtTotal
						,@ExtTotal -- amount
						,@CrDeAmount
						,@SalesDetailId
						,@BillQty*-1)
                END
                ELSE
                BEGIN
                    --If it's Inventory (ISALES, COGS, INV Account)
					INSERT INTO TransactionJournalDetail
							([TxId]
							,[AccountId]
							,[PayeeId]
							,[ItemId]
							,[Qty]
							,[Price]
							,[BillQty]
							,[Amount]
							,[CrDeAmount]
							,[SourceDetailId]
							,[FactorToBase]
							,[InventoryQty])
					VALUES
							(@TxId
							,@AccountId
							,@PayeeId
							,@ItemId
							,@BillQty
							,@UnitPrice
							,@ExtTotal
							,@ExtTotal -- amount
							,@CrDeAmount
							,@SalesDetailId
							,@FactorToBase
							,@BillQty*-1)

					--For COST OF GOOD SOLD account
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'

					INSERT INTO TransactionJournalDetail
							([TxId]
							,[AccountId]
							,[PayeeId]
							,[ItemId]
							,[FactorToBase]
							,[SourceDetailId])
					VALUES
							(@TxId
							,@AccountId
							,@PayeeId
							,@ItemId
							,@FactorToBase
							,@SalesDetailId)

					--For Inventory account
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@INV'

					INSERT INTO TransactionJournalDetail
							([TxId]
							,[AccountId]
							,[PayeeId]
							,[ItemId]
							,[Qty]
							,[Price]
							,[BillQty]
							,[SourceDetailId]
							,[FactorToBase]
							,[InventoryQty])
					VALUES
							(@TxId
							,@AccountId
							,@PayeeId
							,@ItemId
							,@BaseShipQty
							,@UnitPrice
							,@BaseBillQty
							,@SalesDetailId
							,@FactorToBase
							,@BaseBillQty*-1)
                END
            END
        END
        ELSE IF @ChangeStatus = 'U'
        BEGIN
			INSERT INTO @IdMap (TempSalesId, SalesDetailId) VALUES (@TempSalesId_Current, @SalesDetailId);

			SET @ExtTotal= ROUND(@BillQty*@UnitPrice,2)

			UPDATE SalesDetail
			SET
				LineId            = @LineId,
				LineType          = @LineType,
				ItemId            = @ItemId,
				AccountId         = @AccountId,
				ItemUnitId        = @ItemUnitId,
				Unit              = @Unit,
				OrdQty            = @OrdQty,
				ShipQty           = @ShipQty,
				BillQty           = @BillQty,
				UnitPrice         = @UnitPrice,
				ExtTotal          = @ExtTotal,
				Notes             = @Notes,
				IsTaxable         = @IsTaxable,
				OrgPrice          = @OrgPrice,
				DiscountPercent   = @DiscountPercent,
				FactorToBase      = @FactorToBase,
				CartLineType      = @CartLineType,
				IsSystemManaged   = @IsSystemManaged,
				DisplaySort       = @DisplaySort
			FROM SalesDetail
			WHERE SalesDetailId = @SalesDetailId

			--if itemcode is changed then calculate old itemcode too
			SELECT TOP 1 @OldItemId=ItemId
			FROM TransactionJournalDetail
			WHERE TxId=@TxId AND SourceDetailId=@SalesDetailId
			AND AccountId=(SELECT AccountId FROM @AcctTable WHERE AccountCode='@INV')

			IF @OldItemId!=@ItemId
				INSERT INTO RecalculationLog(ItemId,TxId,TxDate) VALUES(@OldItemId,@TxId,@ShipDate)

			-- If It's Account Code
			IF @LineType='A'
			BEGIN
				EXEC Fn_Adjust_CrDeAmount @AccountId,@ExtTotal,@CrDeAmount OUTPUT

				UPDATE TransactionJournalDetail SET
				Qty=@BillQty,
				Price=@UnitPrice,
				BillQty=@ExtTotal,
				Amount=@ExtTotal,
				CrDeAmount=@CrDeAmount,
				ItemId=@ItemId
				WHERE TxId=@TxId AND SourceDetailId=@SalesDetailId
			END
			ELSE
			BEGIN
				 --For NonInventory Logic
				IF @ExtTotal<0
					SET @AccountCode = '@ICREDIT'
				ELSE
					SET @AccountCode = '@ISALE'

				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode=@AccountCode
				EXEC Fn_Adjust_CrDeAmount @AccountId,@ExtTotal,@CrDeAmount OUTPUT

				-- Get the OLD account id from the existing row (must be either @ISALE or @ICREDIT)
				DECLARE @OldAccountId INT;

				SELECT TOP (1) @OldAccountId = tjd.AccountId
				FROM TransactionJournalDetail tjd
				WHERE tjd.TxId = @TxId
				  AND tjd.SourceDetailId = @SalesDetailId
				  AND tjd.AccountId IN (
						(SELECT AccountId FROM @AcctTable WHERE AccountCode='@ISALE'),
						(SELECT AccountId FROM @AcctTable WHERE AccountCode='@ICREDIT')
				  );

				UPDATE TransactionJournalDetail SET
				Qty=@BillQty,
				Price=@UnitPrice,
				BillQty=@ExtTotal,
				Amount=@ExtTotal,
				CrDeAmount=@CrDeAmount,
				ItemId=@ItemId,
				AccountId=@AccountId,  --new accountid
				InventoryQty=@BillQty*-1,
				FactorToBase=@FactorToBase
				WHERE TxId=@TxId AND SourceDetailId=@SalesDetailId AND AccountId=@OldAccountId

				IF @ItemType = 'Inventory'
				BEGIN
					---COGS
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'

					UPDATE TransactionJournalDetail SET ItemId=@ItemId,FactorToBase=@FactorToBase
					WHERE TxId=@TxId AND SourceDetailId=@SalesDetailId AND AccountId=@AccountId

					---INV
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@INV'

					UPDATE TransactionJournalDetail SET
					Qty=@BaseShipQty,
					Price=@UnitPrice,
					BillQty=@BaseBillQty,
					ItemId=@ItemId,
					InventoryQty=@BaseBillQty*-1,
					FactorToBase=@FactorToBase
					WHERE TxId=@TxId AND SourceDetailId=@SalesDetailId AND AccountId=@AccountId
				END
			END
        END
        ELSE IF @ChangeStatus = 'D'
        BEGIN
            DELETE FROM SalesDetail WHERE SalesDetailId=@SalesDetailId

			DELETE FROM TransactionJournalDetail WHERE SourceDetailId=@SalesDetailId AND TxId=@TxId
        END

		SET @RowNum+=1
	END

	-- Translate ParentTempSalesId/RootTempSalesId â†’ ParentSalesDetailId/RootSalesDetailId for new rows only
	UPDATE sd
	SET sd.ParentSalesDetailId = pmap.SalesDetailId,
		sd.RootSalesDetailId = ISNULL(rmap.SalesDetailId, pmap.SalesDetailId)
	FROM SalesDetail sd
	INNER JOIN @IdMap m ON m.SalesDetailId = sd.SalesDetailId
	INNER JOIN @TempSaleTable t ON t.TempSalesId = m.TempSalesId
	LEFT JOIN @IdMap pmap ON pmap.TempSalesId = t.ParentTempSalesId
	LEFT JOIN @IdMap rmap ON rmap.TempSalesId = t.RootTempSalesId
	WHERE t.ChangeStatus = 'I'
	  AND (t.ParentTempSalesId IS NOT NULL OR t.RootTempSalesId IS NOT NULL);

	INSERT INTO RecalculationLog(ItemId,TxId,TxDate)
	SELECT ItemId,@TxId,@ShipDate FROM @TempSaleTable WHERE ChangeStatus IS NOT NULL AND LineType='I'

	DECLARE @SalesTotal DECIMAL(18,2);
	DECLARE @TaxTotal DECIMAL(18,2);

	EXEC [Sales_CalcTotal] @SalesId,@SalesTotal OUTPUT

	UPDATE Sales SET Updateby=@EmpId,UpdatedAt=GETUTCDATE() WHERE SalesId=@SalesId

	SELECT @TaxTotal=TaxTotal FROM Sales WHERE SalesId=@SalesId

	--update @AR account
	SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@AR'
	EXEC Fn_Adjust_CrDeAmount @AccountId,@SalesTotal,@CrDeAmount OUTPUT

	UPDATE TransactionJournalDetail
	SET Amount=@SalesTotal,CrDeAmount=@CrDeAmount
	WHERE TxId=@TxId AND AccountId=@AccountId

	--insert and update sales tax account
	SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@FSTP'

	IF @TaxTotal<>0
	BEGIN
		EXEC Fn_Adjust_CrDeAmount @AccountId,@TaxTotal,@CrDeAmount OUTPUT

		--check if sales tax account exist or not
		DECLARE @SalesTaxExist INT
		SELECT @SalesTaxExist=COUNT(*) FROM TransactionJournalDetail WHERE TxId=@TxId AND AccountId=@AccountId

		IF @SalesTaxExist=0
		BEGIN
			INSERT INTO [TransactionJournalDetail]
				([TxId]
				,[AccountId]
				,[Amount]
				,[CrDeAmount])
			VALUES
			   (@TxId
			   ,@AccountId
			   ,@TaxTotal
			   ,@CrDeAmount)
		END
		ELSE
			UPDATE TransactionJournalDetail SET Amount=@TaxTotal,CrDeAmount=@CrDeAmount
			WHERE TxId=@TxId AND AccountId=@AccountId
	END
	ELSE
		DELETE FROM TransactionJournalDetail WHERE TxId=@TxId AND AccountId=@AccountId

	-- Clean up TempSalesPromo links before deleting TempSales (FK constraint)
	DELETE tsp
	FROM TempSalesPromo tsp
	WHERE EXISTS (
		SELECT 1
		FROM TempSales ts
		WHERE ts.PayeeId = @PayeeId
		  AND ts.EmpId = @EmpId
		  AND ts.SalesId = @SalesId
		  AND (
				ts.TempSalesId = tsp.OwnerTempSalesId
			 OR ts.TempSalesId = tsp.PromoTempSalesId
		  )
	);

	DELETE TempSales WHERE PayeeId=@PayeeId AND EmpId=@EmpId AND SalesId=@SalesId

END


GO




-- Phase 2F: Sales_Inject — Reverse-map parent/root + refresh DisplaySort on PROMO_REWARD
-- Changes:
--   1. After INSERT INTO TempSales, UPDATE parent/root references using SalesDetailId mapping
--   2. Refresh DisplaySort on PROMO_REWARD rows to match owner's current LineId

ALTER PROCEDURE [dbo].[Sales_Inject]
    @EmpId INT,
    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @PayeeId INT
    SELECT @PayeeId=ShipId FROM Sales WHERE SalesId=@SalesId

    DELETE FROM TempSales WHERE PayeeId=@PayeeId AND EmpId=@EmpId AND SalesId=@SalesId

    INSERT INTO [TempSales]
           ([EmpId]
           ,[SalesId]
           ,[PayeeId]
           ,[LineType]
           ,[ItemId]
           ,[AccountId]
           ,[ItemUnitId]
           ,[Unit]
           ,[IsFree]
           ,[IsOut]
           ,[IsCRCG]
           ,[OrdQty]
           ,[ShipQty]
           ,[BillQty]
           ,[UnitPrice]
           ,[ExtTotal]
           ,[Notes]
           ,[IsTaxable]
           ,[OrgPrice]
           ,[DiscountPercent]
           ,[FactorToBase]
           ,[SalesDetailId]
           ,[ParentTempSalesId]
           ,[RootTempSalesId]
           ,[CartLineType]
           ,[IsSystemManaged]
           ,[DisplaySort])
    SELECT
            @EmpId
           ,[SalesId]
           ,@PayeeId
           ,[LineType]
           ,[ItemId]
           ,[AccountId]
           ,[ItemUnitId]
           ,[Unit]
           ,CASE WHEN (sd.BillQty=0 AND sd.ShipQty!=0) THEN 1 ELSE 0 END --Free
           ,CASE WHEN (sd.BillQty=0 AND sd.ShipQty=0) THEN 1 ELSE 0 END  --Out
           ,CASE WHEN (sd.BillQty!=0 AND sd.ShipQty=0) THEN 1 ELSE 0 END --Credit
           ,[OrdQty]
           ,[ShipQty]
           ,[BillQty]
           ,[UnitPrice]
           ,[ExtTotal]
           ,[Notes]
           ,[IsTaxable]
           ,[OrgPrice]
           ,[DiscountPercent]
           ,[FactorToBase]
           ,[SalesDetailId]
           ,NULL  -- ParentTempSalesId (populated below)
           ,NULL  -- RootTempSalesId (populated below)
           ,ISNULL([CartLineType], 'MAIN')
           ,ISNULL([IsSystemManaged], 0)
           ,[DisplaySort]
    FROM SalesDetail AS sd WHERE SalesId=@SalesId ORDER BY sd.LineId

    -- Phase 2E: Reverse-map parent/root references using SalesDetailId
    -- TempSales.SalesDetailId stores the source SalesDetailId, so we can join directly
    UPDATE ts
    SET ts.ParentTempSalesId = pts.TempSalesId,
        ts.RootTempSalesId = ISNULL(rts.TempSalesId, pts.TempSalesId)
    FROM TempSales ts
    INNER JOIN SalesDetail sd ON sd.SalesDetailId = ts.SalesDetailId
    LEFT JOIN TempSales pts ON pts.SalesDetailId = sd.ParentSalesDetailId
        AND pts.EmpId = @EmpId AND pts.SalesId = @SalesId AND pts.PayeeId = @PayeeId
    LEFT JOIN TempSales rts ON rts.SalesDetailId = sd.RootSalesDetailId
        AND rts.EmpId = @EmpId AND rts.SalesId = @SalesId AND rts.PayeeId = @PayeeId
    WHERE ts.EmpId = @EmpId AND ts.SalesId = @SalesId AND ts.PayeeId = @PayeeId
        AND sd.ParentSalesDetailId IS NOT NULL;

    -- Refresh DisplaySort on PROMO_REWARD rows to match owner's current LineId
    UPDATE ts
    SET ts.DisplaySort = owner.LineId
    FROM TempSales ts
    INNER JOIN TempSales owner ON owner.TempSalesId = ts.ParentTempSalesId
    WHERE ts.CartLineType = 'PROMO_REWARD'
      AND ts.EmpId = @EmpId
      AND ts.SalesId = @SalesId
      AND ts.PayeeId = @PayeeId;
END




-- Baseline dumped from live DB: 2026-04-16
-- Rollback: restores TRG_Update_TempSalesReSeq to pre-feature state

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER TRIGGER [dbo].[TRG_Update_TempSalesReSeq]
ON [dbo].[TempSales]
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- 1. Find all (EmpId, PayeeId, PurchaseId) affected by this change
    ;WITH Changed AS
    (
        SELECT DISTINCT EmpId, PayeeId, SalesId
        FROM inserted
        WHERE EmpId IS NOT NULL 
          AND PayeeId IS NOT NULL 
          AND SalesId IS NOT NULL
        UNION
        SELECT DISTINCT EmpId, PayeeId, SalesId
        FROM deleted
        WHERE EmpId IS NOT NULL 
          AND PayeeId IS NOT NULL 
          AND SalesId IS NOT NULL
    ),
    -- 2. For those groups, recompute LineId = 1,2,3,... 
    Renumber AS
    (
        SELECT 
            T.TempSalesId,
            ROW_NUMBER() OVER (
                PARTITION BY T.EmpId, T.PayeeId, T.SalesId
                ORDER BY T.LineId, T.TempSalesId     -- choose your order
            ) AS NewLineId
        FROM TempSales T
        JOIN Changed C
          ON  C.EmpId   = T.EmpId
          AND C.PayeeId = T.PayeeId
          AND C.SalesId = T.SalesId
    )
    UPDATE T
    SET T.LineId = R.NewLineId
    FROM TempSales T
    JOIN Renumber R
      ON T.TempSalesId = R.TempSalesId;
END;

