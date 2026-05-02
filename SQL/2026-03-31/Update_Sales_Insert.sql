ALTER PROCEDURE [dbo].[Sales_Insert]
	@SalesId INT,
	@PayeeId INT,
	@ShipDate DATE,
	@ShipRoute NVARCHAR(10),
	@Instruction NVARCHAR(300) = 'Web',
	@StageId INT,
	@EmpId INT,
	@NewSalesId INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @TermId INT;
    DECLARE @SalesNumber INT
    DECLARE @SalesDate DATETIME = GETUTCDATE()
    DECLARE @BillId INT
    DECLARE @TaxRate DECIMAL(18,4)
    DECLARE @RCExpireDate DATE
    DECLARE @SalesRepId INT
    DECLARE @IsCreditHold BIT
    DECLARE @IsStatementPrint BIT
    DECLARE @ShippingCarrierId INT
    DECLARE @SalesTotal DECIMAL(18,2)
    DECLARE @TaxTotal DECIMAL(18,2)

    DECLARE @TxId BIGINT;
    DECLARE @CrDeAmount DECIMAL(18,2)=0;
	DECLARE @AccountId INT
    DECLARE @AccountCode NVARCHAR(50)

    DECLARE @DocOrder INT;
    DECLARE @DocType NVARCHAR(100) = 'Sales';
    EXEC [Get_SourceDocOrder] @DocType, @DocOrder OUTPUT;

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

	SELECT @TermId=TermId,
    @BillId=ISNULL(BillId,p.PayeeId),
    @TaxRate=TaxRate,
    @RCExpireDate=RCExpireDate,
    @SalesRepId=ISNULL(SalesRepId,@EmpId),
    @IsCreditHold=IsCreditHold,
    @ShippingCarrierId=ShippingCarrierId,
    @IsStatementPrint=IsStatementPrint
	FROM Payee As p INNER JOIN Customer AS c ON p.PayeeId=c.PayeeId
    WHERE p.PayeeId=@PayeeId

	IF @SalesId>0
		SET @SalesNumber = @SalesId ---use in Merge Order
	ELSE
		SET @SalesNumber = NEXT VALUE FOR dbo.Seq_SalesNumber;

	IF @ShipDate IS NULL
		EXEC dbo.Fn_Calc_NextShipDate @PayeeId,@ShipDate OUTPUT

    IF @ShipRoute='CM'
        EXEC [Get_TodayLocalDate] @ShipDate OUTPUT

	INSERT INTO [dbo].[Sales]
           ([SalesNumber]
           ,[StageId]
           ,[SalesDate]
           ,[ShipDate]
           ,[ShipRoute]
           ,[ShipId]
           ,[BillId]
           ,[SalesRepId]
           ,[TermId]
           ,[SubTotal]
           ,[TaxableTotal]
           ,[TaxPercent]
           ,[TaxTotal]
           ,[SalesTotal]
           ,[AmountDue]
           ,[Instruction]
           ,[ShippingCarrierId]
           ,[IsLoadSeparate]
           ,[IsLocked]
           ,[IsStatementAttached]
           ,[Enterby]
           ,[CreatedAt])
     VALUES
           (@SalesNumber
           ,@StageId
           ,@SalesDate
           ,@ShipDate
           ,@ShipRoute
           ,@PayeeId
           ,@BillId
           ,@SalesRepId
           ,@TermId
           ,0
           ,0
           ,@TaxRate
           ,0
           ,0
           ,0
           ,@Instruction
           ,@ShippingCarrierId
           ,0
           ,0
           ,@IsStatementPrint
           ,@EmpId
           ,@SalesDate)

    SELECT @SalesId = SCOPE_IDENTITY();

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
     SELECT @SalesId
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
           ,CASE
				WHEN LineType='A' THEN 0
				ELSE
				(Select IsTaxable FROM dbo.Fn_IsItemTaxable(ItemId,@ShipDate,@PayeeId))
			END
           ,[OrgPrice]
           ,[DiscountPercent]
           ,[FactorToBase]
           ,NULL  -- ParentSalesDetailId (ID translation deferred)
           ,NULL  -- RootSalesDetailId (ID translation deferred)
           ,[CartLineType]
           ,[IsSystemManaged]
           ,[DisplaySort]
    FROM TempSales WHERE EmpId=@EmpId AND PayeeId=@PayeeId AND SalesId=0 AND IsStrike=0
    ORDER BY LineId

    EXEC [Sales_CalcTotal] @SalesId,@SalesTotal OUTPUT

    SELECT @TaxTotal=TaxTotal FROM Sales WHERE SalesId=@SalesId

    ------- END OF SOURCE TABLE (Sales, SalesDetail, Payee) ---------

    CREATE TABLE #SalTxDetail
	(
		TxDetailId int IDENTITY(1,1),
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
	)

    INSERT INTO [dbo].[TransactionJournal]
			([TxDate]
			,[TxTime]
			,[SourceDocOrder]
			,[SourceDocType]
			,[SourceDocNumber])
		VALUES
			(@ShipDate
			,GETUTCDATE()
			,@DocOrder
			,@DocType
			,@SalesNumber)

    SELECT @TxId = SCOPE_IDENTITY();

	SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@AR'
	EXEC Fn_Adjust_CrDeAmount @AccountId,@SalesTotal,@CrDeAmount OUTPUT

    INSERT INTO #SalTxDetail
			([TxId]
			,[AccountId]
			,[PayeeId]
			,[Amount]
			,[CrDeAmount])
		VALUES
			(@TxId
			,@AccountId
			,@PayeeId
			,@SalesTotal
			,@CrDeAmount)

    IF @TaxTotal<>0
    BEGIN
        SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@FSTP'
	    EXEC Fn_Adjust_CrDeAmount @AccountId,@TaxTotal,@CrDeAmount OUTPUT

        INSERT INTO #SalTxDetail
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

    --- for multiple Items ---
    DECLARE @LineType NVARCHAR(1)
	DECLARE @ItemId INT
	DECLARE @ItemAccountId INT
	DECLARE @ItemType NVARCHAR(50)
	DECLARE @OrdQty DECIMAL(18,2)
    DECLARE @ShipQty DECIMAL(18,2)
	DECLARE @BillQty DECIMAL(18,2)
    DECLARE @UnitPrice DECIMAL(18,2)
	DECLARE @BaseShipQty DECIMAL(18,6)
	DECLARE @BaseBillQty DECIMAL(18,6)
	DECLARE @FactorToBase DECIMAL(18,6)
	DECLARE @SDId INT

    DECLARE @ExtTotal DECIMAL(18,2)

    DECLARE @ItmTable TABLE (
		[AutoId] [int] IDENTITY(1,1) NOT NULL,
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
	)

    INSERT INTO @ItmTable
	SELECT sd.LineType
		,sd.ItemId
		,sd.AccountId
		,i.ItemType
		,OrdQty
		,ShipQty
		,BillQty
		,UnitPrice
		,sd.BaseShipQty
		,sd.BaseBillQty
		,sd.FactorToBase
		,SalesDetailId
	FROM SalesDetail as sd LEFT JOIN Item as i on sd.ItemId=i.ItemId
	WHERE SalesId=@SalesId ORDER BY SalesDetailId

    DECLARE @RowNum INT = 1
	DECLARE @MaxRow INT

	SELECT @MaxRow = COUNT(AutoId) FROM @ItmTable

    WHILE @RowNum <= @MaxRow
	BEGIN
        SELECT
			@LineType=LineType,
			@ItemId=ItemId,
			@ItemAccountId=AccountId,
			@ItemType=ItemType,
			@OrdQty=OrdQty,
			@ShipQty=ShipQty,
			@BillQty=BillQty,
			@UnitPrice=UnitPrice,
			@BaseShipQty=BaseShipQty,
			@BaseBillQty=BaseBillQty,
			@FactorToBase=FactorToBase,
			@SDId=SDId
		FROM @ItmTable WHERE AutoId=@RowNum

        SET @ExtTotal = ROUND(@BillQty*@UnitPrice,2)

        -- If It's Account Code
		IF @LineType='A'
		BEGIN
            EXEC Fn_Adjust_CrDeAmount @ItemAccountId,@ExtTotal,@CrDeAmount OUTPUT

            INSERT INTO #SalTxDetail
					([TxId]
					,[AccountId]
					,[PayeeId]
					,[Qty]
					,[Price]
					,[BillQty]
					,[Amount]
					,[CrDeAmount]
					,[SrcDetailId])
				VALUES
					(@TxId
					,@ItemAccountId
					,@PayeeId
					,@BillQty
					,@UnitPrice
					,@ExtTotal
					,@ExtTotal -- amount
					,@CrDeAmount
					,@SDId)
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
                INSERT INTO #SalTxDetail
						([TxId]
						,[AccountId]
						,[PayeeId]
						,[ItemId]
                        ,[Qty]
						,[Price]
						,[BillQty]
						,[Amount]
						,[CrDeAmount]
						,[SrcDetailId]
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
						,@SDId
						,@BillQty*-1)
            END
            ELSE
            BEGIN
                --If it's Inventory (ISALES, COGS, INV Account)
                INSERT INTO #SalTxDetail
						([TxId]
						,[AccountId]
						,[PayeeId]
						,[ItemId]
                        ,[Qty]
						,[Price]
						,[BillQty]
						,[Amount]
						,[CrDeAmount]
						,[SrcDetailId]
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
						,@SDId
						,@FactorToBase
						,@BillQty*-1)

				--For COST OF GOOD SOLD account
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'

				INSERT INTO #SalTxDetail
						([TxId]
						,[AccountId]
						,[PayeeId]
						,[ItemId]
						,[FactorToBase]
						,[SrcDetailId])
				VALUES
						(@TxId
						,@AccountId
						,@PayeeId
						,@ItemId
						,@FactorToBase
						,@SDId)

				--For Inventory account
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@INV'

				INSERT INTO #SalTxDetail
						([TxId]
						,[AccountId]
						,[PayeeId]
						,[ItemId]
                        ,[Qty]
						,[Price]
						,[BillQty]
						,[SrcDetailId]
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
						,@SDId
						,@FactorToBase
						,@BaseBillQty*-1)
            END
        END

		SET @RowNum +=1
    END

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
	SELECT [TxId]
			,[AccountId]
			,[PayeeId]
			,[ItemId]
			,[Qty]
			,[Price]
			,[BillQty]
			,[Amount]
			,[CrDeAmount]
			,[SrcDetailId]
			,[FactorToBase]
			,[InventoryQty]
	FROM #SalTxDetail
	ORDER BY TxDetailId

	DELETE TempSales WHERE PayeeId=@PayeeId AND EmpId=@EmpId

	SET @NewSalesId = @SalesId

	EXEC Recalc_AfterInsert @TxId,@ShipDate
END
