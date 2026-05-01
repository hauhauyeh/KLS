-- Consolidated purchase posting rollback bundle
-- Restores live baseline captured before 2026-04-16 purchase refactor

 
CREATE PROCEDURE [dbo].[Purchase_CalcTotalAndPercent]
 
	@PurchaseId INT,
	@FinalTotal DECIMAL(18,2) OUTPUT
AS
BEGIN
 
	SET NOCOUNT ON;
 
	--Calculate purchase total,aging,freight

	DECLARE @BillTotal DECIMAL(18,2);

	DECLARE @Aging INT=0;
	DECLARE @InvoiceAging INT=0;
	DECLARE @DueDate DATE;
	DECLARE @DiscDate DATE
	DECLARE @DiscRate DECIMAL(18,4)
	DECLARE @AmountDue DECIMAL(18,2);
	DECLARE @PaymentApplied DECIMAL(18,2);
	DECLARE @DiscountApplied DECIMAL(18,2);
	DECLARE @IsLocked BIT=0;	
	DECLARE @IsFreightOnly BIT=0
	DECLARE @FreightInside DECIMAL(18,2);
	DECLARE @CustomDutyInside DECIMAL(18,2);

	DECLARE @ArrivalDate DATE
	DECLARE @TermId INT;
	DECLARE @PayeeId INT

	SELECT @BillTotal=ISNULL(SUM(ROUND((BillQty * BillPrice),2)),0),
	@FinalTotal=ISNULL(SUM(ROUND((FinalQty * FinalPrice),2)),0) 
	FROM PurchaseDetail WHERE PurchaseId=@PurchaseId

	SELECT 
	@ArrivalDate=ArrivalDate,
	@DueDate=DueDate,
	@TermId=TermId,
	@PayeeId=PayeeId
	FROM Purchase WHERE PurchaseId=@PurchaseId

	IF @DueDate IS NULL
		EXEC Fn_Calc_DueDate @ArrivalDate,@TermId,@DueDate OUTPUT,@DiscDate OUTPUT,@DiscRate OUTPUT

	--Calculate Aging
	EXEC Fn_Calc_Aging @ArrivalDate,@PayeeId,@FinalTotal,@Aging OUTPUT,@InvoiceAging OUTPUT

	SELECT @FreightInside=SUM(ROUND(FinalQty*FinalPrice,2)) 
	FROM PurchaseDetail As pd inner join Account AS a ON a.AccountId=pd.AccountId 
	WHERE PurchaseId=@PurchaseId AND a.AccountCode in ('@COGSF','@INVC')

	SELECT @CustomDutyInside=SUM(ROUND(FinalQty*FinalPrice,2)) 
	FROM PurchaseDetail As pd inner join Account AS a ON a.AccountId=pd.AccountId 
	WHERE PurchaseId=@PurchaseId AND a.AccountCode='@CD'

	SET @IsFreightOnly =
	IIF(
      EXISTS (SELECT 1 FROM PurchaseDetail WHERE PurchaseId = @PurchaseId)
      AND NOT EXISTS (
          SELECT 1
          FROM PurchaseDetail pd
          LEFT JOIN Account a ON a.AccountId = pd.AccountId
          WHERE pd.PurchaseId = @PurchaseId
            AND (
                  pd.ItemId IS NOT NULL
                  OR a.AccountId IS NULL
				  OR a.AccountCode NOT IN ('@INVC')
                  --OR a.AccountCode NOT IN ('@COGSF', '@CD', '@INVC')
                )
		),
      1, 0
	);

	SELECT 
	@PaymentApplied = ISNULL(SUM(PaymentApplied), 0),
	@DiscountApplied = ISNULL(SUM(DiscountApplied), 0) 
	FROM VendorPaymentDetail WHERE PurchaseId = @PurchaseId;
		
	IF (@PaymentApplied!=0 OR @DiscountApplied!=0)
		SET @AmountDue=@FinalTotal-(@PaymentApplied+@DiscountApplied)
	ELSE
		SET @AmountDue=@FinalTotal

	UPDATE Purchase	SET 
		VendorTotal=@BillTotal,
		PurchaseTotal=@FinalTotal,
		AmountDue=@AmountDue,
		PaymentApplied=@PaymentApplied,
		DiscountApplied=@DiscountApplied,
		Aging=@Aging,
		InvoiceAging=@InvoiceAging,
		DueDate=@DueDate,
		--FreightInside=@FreightInside,
		IsFreightOnly=@IsFreightOnly,
		--CustomDutyInside=@CustomDutyInside,
		UpdatedAt=GETUTCDATE()
	WHERE PurchaseId=@PurchaseId

	-- Calculate Base Qty
	;WITH cte AS
	(
		SELECT *,
			   ROW_NUMBER() OVER (ORDER BY LineId) AS NewLineId
		FROM PurchaseDetail
		WHERE PurchaseId = @PurchaseId
	)
	UPDATE cte
	SET 
		LineId = NewLineId,
		BaseReceiveQty = ROUND(ReceiveQty / FactorToBase, 6),
		BaseFinalQty   = ROUND(FinalQty / FactorToBase, 6);

	-- Calculate Duty Percent
	--;WITH duty AS
 --   (
 --       SELECT
	--		pd.PurchaseId,
 --           pd.PurchaseDetailId,
 --           pd.BaseFinalQty,
	--		Price = pd.FinalPrice,
	--		TempDuty = ROUND(
	--			pd.FinalPrice * 
	--			CAST(ISNULL(pd.CustomDutyRate,0) + ISNULL(pd.TariffPercent,0) AS decimal(18,6)),
	--		4),
	--		LineVolume = ROUND(pd.BaseFinalQty * pd.ItemVolume,4)
 --       FROM dbo.PurchaseDetail AS pd
 --       WHERE pd.PurchaseId = @PurchaseId AND pd.ItemId IS NOT NULL
 --   ),
 --   calc AS
	--(
	--	SELECT *,
	--		LineDuty = TempDuty*BaseFinalQty,
	--		TotalDuty = SUM(TempDuty*BaseFinalQty) OVER (PARTITION BY PurchaseId),
	--		TotalVolume = SUM(LineVolume) OVER (PARTITION BY PurchaseId)
	--	FROM duty
	--)

 --   UPDATE pd
 --   SET
 --       pd.DutySharePercent   = ROUND(c.LineDuty   / NULLIF(c.TotalDuty,   0), 4),
 --       pd.VolumeSharePercent = ROUND(c.LineVolume / NULLIF(c.TotalVolume, 0), 4)
 --   FROM dbo.PurchaseDetail AS pd
 --   JOIN calc AS c ON c.PurchaseDetailId = pd.PurchaseDetailId

	EXEC [Payee_UpdateAging] @PayeeId,0

	-- Update stage
	UPDATE p
	SET StageId =
    CASE
		/* 6 - Billed : */
		WHEN StageId = 6 THEN 6

        /* 5 - Received : all lines received */
        WHEN NOT EXISTS (
            SELECT 1
            FROM PurchaseDetail pd
            WHERE pd.PurchaseId = p.PurchaseId
              AND pd.ReceiveQty IS NULL AND ItemId IS NOT NULL
        )
        THEN 5   -- Received

        /* 4 - Partially Received : some received */
        WHEN EXISTS (
            SELECT 1
            FROM PurchaseDetail pd
            WHERE pd.PurchaseId = p.PurchaseId
              AND pd.ReceiveQty IS NOT NULL AND ItemId IS NOT NULL
        )
        THEN 4   -- Partially Received

        /* 3 - Shipped : all lines shipped */
        WHEN NOT EXISTS (
            SELECT 1
            FROM PurchaseDetail pd
            WHERE pd.PurchaseId = p.PurchaseId
              AND pd.ShipQty IS NULL AND ItemId IS NOT NULL
        )
        THEN 3   -- Shipped

        /* 2 - Partially Shipped : some shipped */
        WHEN EXISTS (
            SELECT 1
            FROM PurchaseDetail pd
            WHERE pd.PurchaseId = p.PurchaseId
              AND pd.ShipQty IS NOT NULL AND ItemId IS NOT NULL
        )
        THEN 2   -- Partially Shipped

        /* 1 - Ordered */
        ELSE 1   -- Ordered
    END
	FROM Purchase p
	WHERE p.PurchaseId = @PurchaseId and IsStartFromPO=1;


	----Update ItemUnit RecentCost

	;WITH LatestCost AS
	(
		SELECT ItemId, TotalCost
		FROM dbo.View_PurchaseHistory
		WHERE RN = 1 AND PurchaseId = @PurchaseId
	)

	UPDATE iu
	SET iu.RecentCost = ROUND(lc.TotalCost / NULLIF(iu.FactorToBase, 0), 2)
	FROM dbo.ItemUnit iu
	INNER JOIN LatestCost lc ON lc.ItemId = iu.ItemId;

END





GO


CREATE PROCEDURE [dbo].[Purchase_Insert]
	
	@PurchaseId int,
	@PayeeId int,
	@VendorDocNumber nvarchar(100),
	@ContainerNumber nvarchar(100),
	@PurchaseDate date,
	@ArrivalDate date,
	@InvoiceDate date,
	@DueDate date,
	@Notes nvarchar(500),
	@StageId int,
	@PalletCount int,
	@EmpId int,
	@NewPurchaseId INT OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET @ArrivalDate = ISNULL(@ArrivalDate,GETDATE())

	IF EXISTS (SELECT 1 FROM Purchase WHERE PayeeId = @PayeeId
      AND VendorDocNumber = @VendorDocNumber
      AND PurchaseId != @PurchaseId
	)
	BEGIN
		RAISERROR('Vendor DocNum already exists.', 16, 1);
		RETURN;
	END

	DECLARE @AcctTable AS Table(
		Id INT IDENTITY(1,1),
		AccountCode NVARCHAR(50),
		AccountId INT
	)

	INSERT INTO @AcctTable(AccountCode) VALUES('@AP')
	INSERT INTO @AcctTable(AccountCode) VALUES('@COGS')
	INSERT INTO @AcctTable(AccountCode) VALUES('@INV')
	
	UPDATE t SET t.AccountId=a.AccountId
	FROM @AcctTable AS t INNER JOIN Account AS a ON t.AccountCode=a.AccountCode

	DECLARE @OldPurchaseId INT = @PurchaseId;
	DECLARE @TxId BIGINT;
	DECLARE @CrDeAmount DECIMAL(18,2)=0;
	DECLARE @AccountId INT
	DECLARE @TermId INT;
	DECLARE @IsEdit bit=0
	DECLARE @PurchaseNumber INT = 0;
	DECLARE @FinalTotal DECIMAL(18,2);
	DECLARE @CreatedAt DATETIME = GETUTCDATE()

	DECLARE @DocOrder INT;
    DECLARE @DocType NVARCHAR(100) = 'Purchase';
    EXEC [Get_SourceDocOrder] @DocType, @DocOrder OUTPUT;

	SELECT @TermId=TermId FROM Payee WHERE PayeeId=@PayeeId

	SET @PurchaseNumber = NEXT VALUE FOR dbo.Seq_PurchaseNumber;

	INSERT INTO [dbo].[Purchase]
           ([PurchaseNumber]
           ,[StageId]
           ,[PayeeId]
           ,[PurchaseDate]
           ,[EnterDate]
           ,[ArrivalDate]
           ,[InvoiceDate]
           ,[VendorDocNumber]
           ,[ContainerNumber]
           ,[TermId]
           ,[VendorTotal]
           ,[PurchaseTotal]
           ,[AmountDue]
           ,[PaymentApplied]
           ,[DiscountApplied]
           ,[Notes]
           ,[IsLocked]
           ,[PalletCount]
		   ,[DueDate]
           ,[CreatedAt])
     VALUES
           (@PurchaseNumber
           ,@StageId
           ,@PayeeId
           ,ISNULL(@PurchaseDate,GETDATE())
           ,GETDATE()
           ,@ArrivalDate
           ,@InvoiceDate
           ,@VendorDocNumber
           ,@ContainerNumber
           ,@TermId
           ,0
           ,0
           ,0
           ,0
           ,0
           ,@Notes
           ,0
           ,@PalletCount
		   ,@DueDate
           ,@CreatedAt)

	SELECT @PurchaseId = SCOPE_IDENTITY();

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
           ,[ExpiryDate]
           ,[DiscountPercent]
           ,[Discount]
           ,[OrgPrice]
           ,[CustomDutyRate]
		   ,[TariffPercent]
           ,[ItemVolume])
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
           ,[DiscountPercent]
           ,[Discount]
           ,[OrgPrice]
           ,[CustomDutyRate]
		   ,[TariffPercent]
           ,[ItemVolume]
	FROM TempPurchase WHERE EmpId=@EmpId and PayeeId=@PayeeId
	AND PurchaseId = CASE WHEN @IsEdit=1 THEN @OldPurchaseId ELSE 0 END
	ORDER BY LineId

	EXEC [Purchase_CalcTotalAndPercent] @PurchaseId,@FinalTotal OUTPUT

	------------------- END OF SOURCE TABLE ------------------------------
	
	CREATE TABLE #PurTxDetail
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
			(@ArrivalDate
			,GETUTCDATE()
			,@DocOrder
			,@DocType
			,@PurchaseNumber)

	SELECT @TxId = SCOPE_IDENTITY();

	SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@AP'
	EXEC Fn_Adjust_CrDeAmount @AccountId,@FinalTotal,@CrDeAmount OUTPUT

	INSERT INTO #PurTxDetail
			([TxId]
			,[AccountId]
			,[PayeeId]	
			,[Amount]
			,[CrDeAmount])
		VALUES
			(@TxId
			,@AccountId
			,@PayeeId
			,@FinalTotal
			,@CrDeAmount)

	--for multiple product purchase
	DECLARE @LineType NVARCHAR(1)
	DECLARE @MyItemId INT
	DECLARE @MyAccountId INT
	DECLARE @MyItemType NVARCHAR(50)
	DECLARE @FinalQty DECIMAL(18,2)
	DECLARE @BaseReceiveQty DECIMAL(18,6)
	DECLARE @BaseFinalQty DECIMAL(18,6)
	DECLARE @MyFinalPrice DECIMAL(18,2)
	DECLARE @FactorToBase DECIMAL(18,6)
	DECLARE @SDId INT
	DECLARE @DefaultCost DECIMAL(18,2)

	DECLARE @COGSExtTotal DECIMAL(18,2)
	DECLARE @ExpenseExtTotal DECIMAL(18,2)
	DECLARE @ConvertedPrice DECIMAL(18,6)
	DECLARE @X DECIMAL(18,2)
	DECLARE @IsAccountDebit BIT

	DECLARE @MyTable TABLE (
		[AutoId] [int] IDENTITY(1,1) NOT NULL,
		[LineType] NVARCHAR(1),
		[ItemId] INT NULL,
		[AccountId] INT NULL,
		[ItemType] [nvarchar](50) NULL,
		[FinalQty] DECIMAL(18,2) NULL,
		[BaseReceiveQty] DECIMAL(18,6) NULL,
		[BaseFinalQty] DECIMAL(18,6) NULL,
		[FinalPrice] DECIMAL(18,4) NULL,
		[FactorToBase] DECIMAL(18,6),
		[SDId] INT
	)

	INSERT INTO @MyTable
	SELECT pd.LineType
		,pd.ItemId
		,pd.AccountId
		,i.ItemType
		,FinalQty
		,BaseReceiveQty
		,BaseFinalQty
		,ROUND(FinalPrice,2)
		,pd.FactorToBase
		,PurchaseDetailId
	FROM PurchaseDetail as pd LEFT JOIN Item as i on pd.ItemId=i.ItemId
	WHERE PurchaseId=@PurchaseId ORDER BY PurchaseDetailId

	DECLARE @RowNum INT=1
	DECLARE @MaxRow INT
	
	SELECT @MaxRow=COUNT(AutoId) FROM @MyTable

	UPDATE Item SET IsCostChange=0

	WHILE @RowNum <= @MaxRow
	BEGIN
		SELECT
			@LineType=LineType,
			@MyItemId=ItemId,
			@MyAccountId=AccountId,
			@MyItemType=ItemType,
			@FinalQty=FinalQty,
			@BaseReceiveQty=BaseReceiveQty,
			@BaseFinalQty=BaseFinalQty,
			@MyFinalPrice=FinalPrice,
			@FactorToBase=FactorToBase,
			@SDId=SDId
		FROM @MyTable WHERE AutoId=@RowNum

		-- If It's Account Code
		IF @LineType='A'
		BEGIN
			SET @ExpenseExtTotal = ROUND(@FinalQty*@MyFinalPrice,2) 
			SELECT @IsAccountDebit=IsAccountDebit FROM Account AS C WHERE AccountId=@MyAccountId

			IF @IsAccountDebit=1
				SET @X = @ExpenseExtTotal
			ELSE
				SET @X = -@ExpenseExtTotal

			EXEC Fn_Adjust_CrDeAmount @MyAccountId,@X,@CrDeAmount OUTPUT

			INSERT INTO #PurTxDetail
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
					,@MyAccountId
					,@PayeeId
					,@FinalQty
					,@MyFinalPrice
					,ABS(@X)
					,@X -- amount
					,@CrDeAmount
					,@SDId)
		END
		ELSE
		BEGIN
			--For NonInventory Logic
			IF @MyItemType = 'NonInventory'
			BEGIN
				--For COGS account
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'
				SET @COGSExtTotal= ROUND(@FinalQty*@MyFinalPrice,2)

				EXEC Fn_Adjust_CrDeAmount @AccountId,@COGSExtTotal,@CrDeAmount OUTPUT

				INSERT INTO #PurTxDetail
						([TxId]
						,[AccountId]
						,[PayeeId]
						,[ItemId]
						,[Amount]
						,[CrDeAmount]
						,[SrcDetailId]
						,[InventoryQty])
				VALUES
						(@TxId
						,@AccountId
						,@PayeeId
						,@MyItemId
						,@COGSExtTotal -- amount
						,@CrDeAmount
						,@SDId
						,@BaseReceiveQty)
			END
			ELSE
			BEGIN
				--Convert Inventory Qty

				--We already convert BaseQty now convert Price
				SET @ConvertedPrice = ROUND(@MyFinalPrice * @FactorToBase,2)

				--Account = '@COGS'
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'

				INSERT INTO #PurTxDetail
						([TxId]
						,[AccountId]
						,[PayeeId]
						,[ItemId]	
						,[Amount]
						,[CrDeAmount]
						,[SrcDetailId]
						,[FactorToBase])
				VALUES
						(@TxId
						,@AccountId
						,@PayeeId
						,@MyItemId
						,0 -- amount
						,0 --@CrDeAmt
						,@SDId
						,@FactorToBase)

				--Account = '@INV'
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@INV'

				INSERT INTO #PurTxDetail
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
						,@MyItemId
						,@BaseReceiveQty
						,@ConvertedPrice
						,@BaseFinalQty	
						,@SDId
						,@FactorToBase
						,@BaseReceiveQty)	
			END

			--IF @DefaultCost!=@MyFinalPrice
			--	UPDATE Item SET IsCostChange=1 WHERE ItemId=@MyItemId
		END

		SET @RowNum += 1
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
	FROM #PurTxDetail AS p
	ORDER BY TxDetailId

	--====================================================================
	DELETE FROM TempPurchase WHERE PayeeId=@PayeeId AND EmpId=@EmpId

	SET @NewPurchaseId = @PurchaseId

	-- call RecalcQAV after insert
	EXEC Recalc_AfterInsert @TxId,@ArrivalDate

END





GO


CREATE PROCEDURE [dbo].[Purchase_PartialUpdate]

	@PurchaseId INT,
	@EmpId INT,
	@IsBill BIT = 1
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @TxId BIGINT
	DECLARE @TxDate DATE
	DECLARE @RowNum INT=1
	DECLARE @MaxRow INT
	DECLARE @PurchaseNumber INT
	DECLARE @ArrivalDate DATE
	DECLARE @IsLocked BIT
	DECLARE @PayeeId int
	DECLARE @StageId INT

	SELECT @PurchaseNumber=PurchaseNumber,
	@ArrivalDate=ArrivalDate,
	@IsLocked=IsLocked,
	@PayeeId=PayeeId,
	@StageId=StageId
	FROM Purchase WHERE PurchaseId=@PurchaseId

	--IF @IsLocked=1
	--BEGIN
	--	RAISERROR('This bill is already paid and locked.', 16, 1);
	--	RETURN;
	--END
	
	DECLARE 
    @AutoId             INT,
    @LineId             INT,
    @LineType           NVARCHAR(1),
    @ItemId             INT,
    @AccountId          INT,
    @ItemUnitId         INT,
    @Unit               NVARCHAR(50),
    @Notes              NVARCHAR(255),
    @IsFree             BIT,
    @IsOut              BIT,
    @IsCRCG             BIT,
    @OrdQty0            DECIMAL(18, 2),
    @ShipQty            DECIMAL(18, 2),
    @BillQty            DECIMAL(18, 2),
    @OrdQty1            DECIMAL(18, 2),
    @ReceiveQty         DECIMAL(18, 2),
    @FinalQty           DECIMAL(18, 2),
    @BillPrice          DECIMAL(18, 2),
    @BillExtTotal       DECIMAL(18, 2),
    @FinalPrice         DECIMAL(18, 2),
	@ImportCommission   DECIMAL(18, 2),
    @FinalExtTotal      DECIMAL(18, 2),
	@FactorToBase       DECIMAL(18, 6),
    @ExpiryDate         DATE, 
    @DiscountPercent    DECIMAL(18, 4),
    @Discount           DECIMAL(18, 2),
    @OrgPrice           DECIMAL(18, 2),
    @CustomDutyRate     DECIMAL(18, 6),
	@TariffPercent     DECIMAL(9, 4),
    --@DutySharePercent   DECIMAL(18, 6),
    @ItemVolume         DECIMAL(18, 4),
    --@VolumeSharePercent DECIMAL(18, 6),
    @ChangeStatus       NVARCHAR(1),
    @PurchaseDetailId   INT;

    DECLARE @ExtTotal DECIMAL(18, 2)
	DECLARE @IsAccountDebit BIT
	DECLARE @X DECIMAL(18, 2)
	DECLARE @CrDeAmount DECIMAL(18, 2)
	DECLARE @ItemType NVARCHAR(100)
	DECLARE @DefaultCost DECIMAL(18, 2)
	DECLARE @OldItemId INT
	DECLARE @AccountCode NVARCHAR(50)
	DECLARE @ConvertedPrice DECIMAL(18,6)
	DECLARE @BaseReceiveQty DECIMAL(18,6)
	DECLARE @BaseFinalQty DECIMAL(18,6)

	DECLARE @AcctTable AS Table(
		Id INT IDENTITY(1,1),
		AccountCode NVARCHAR(50),
		AccountId INT
	)

	INSERT INTO @AcctTable(AccountCode) VALUES('@AP')
	INSERT INTO @AcctTable(AccountCode) VALUES('@COGS')
	INSERT INTO @AcctTable(AccountCode) VALUES('@INV')

	UPDATE t SET t.AccountId=a.AccountId
	FROM @AcctTable AS t INNER JOIN Account AS a ON t.AccountCode=a.AccountCode

	DECLARE @TempTable TABLE (
		[AutoId] [int] IDENTITY(1,1) NOT NULL,
		[LineId] [int] NULL,
		[LineType] [nvarchar](1) NOT NULL,
		[ItemId] [int] NULL,
		[AccountId] [int] NULL,
		[ItemUnitId] [int] NULL,
		[Unit] [nvarchar](50) NULL,
		[Notes] [nvarchar](255) NULL,
		[IsFree] [bit] NOT NULL,
		[IsOut] [bit] NOT NULL,
		[IsCRCG] [bit] NOT NULL,
		[OrdQty0] [decimal](18, 2) NULL,
		[ShipQty] [decimal](18, 2) NULL,
		[BillQty] [decimal](18, 2) NULL,
		[OrdQty1] [decimal](18, 2) NULL,
		[ReceiveQty] [decimal](18, 2) NULL,
		[FinalQty] [decimal](18, 2) NULL,
		[BillPrice] [decimal](18, 2) NULL,
		[BillExtTotal] [decimal](18, 2) NULL,
		[FinalPrice] [decimal](18, 2) NULL,
		[ImportCommission] [decimal](18, 2) NULL,
		[FinalExtTotal] [decimal](18, 2) NULL,
		[FactorToBase] [decimal](18, 6) NULL,
		[ExpiryDate] [date] NULL,
		[DiscountPercent] [decimal](18, 4) NULL,
		[Discount] [decimal](18, 2) NULL,
		[OrgPrice] [decimal](18, 2) NULL,
		[CustomDutyRate] [decimal](18, 6) NULL,
		[TariffPercent] [decimal](9, 4) NULL,
		--[DutySharePercent] [decimal](18, 6) NULL,
		[ItemVolume] [decimal](18, 4) NULL,
		--[VolumeSharePercent] [decimal](18, 6) NULL,
		[ChangeStatus] [nvarchar](1) NULL,
		[PurchaseDetailId] [int] NULL,
		[ItemType] NVARCHAR(100) NULL
		--[DefaultCost] decimal(18, 2) NULL
	)

	INSERT INTO @TempTable
	SELECT [LineId]
      ,[LineType]
      ,t.[ItemId]
      ,[AccountId]
      ,[ItemUnitId]
      ,[Unit]
      ,t.[Notes]
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
      ,t.[ExpiryDate]
      ,[DiscountPercent]
      ,[Discount]
      ,[OrgPrice]
      ,[CustomDutyRate]
	  ,[TariffPercent]
      --,[DutySharePercent]
      ,[ItemVolume]
      --,[VolumeSharePercent]
      ,[ChangeStatus]
      ,[PurchaseDetailId]
	  ,i.ItemType
	  --,i.DefaultCost
	FROM TempPurchase AS t LEFT JOIN Item as i on t.ItemId=i.ItemId
	WHERE EmpId=@EmpId AND PayeeId=@PayeeId AND PurchaseId=@PurchaseId AND ChangeStatus IS NOT NULL

	SELECT @TxId=TxId,@TxDate=TxDate 
	FROM TransactionJournal WHERE SourceDocNumber=@PurchaseNumber AND SourceDocType='Purchase'

	SELECT @MaxRow=COUNT(AutoId) FROM @TempTable

	UPDATE Item SET IsCostChange=0

    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT
            @LineId             = LineId,
            @LineType           = LineType,
            @ItemId             = ItemId,
            @AccountId          = AccountId,
            @ItemUnitId         = ItemUnitId,
            @Unit               = Unit,
            @Notes              = Notes,
            @IsFree             = IsFree,
            @IsOut              = IsOut,
            @IsCRCG             = IsCRCG,
            @OrdQty0            = OrdQty0,
            @ShipQty            = ShipQty,
            @BillQty            = BillQty,
            @OrdQty1            = OrdQty1,
            @ReceiveQty         = ReceiveQty,
            @FinalQty           = FinalQty,
            @BillPrice          = BillPrice,
            @BillExtTotal       = BillExtTotal,
            @FinalPrice         = FinalPrice,
			@ImportCommission   = ImportCommission,
            @FinalExtTotal      = FinalExtTotal,
			@BaseReceiveQty     = ROUND(ReceiveQty / FactorToBase, 6),
			@BaseFinalQty       = ROUND(FinalQty / FactorToBase, 6),
			@FactorToBase       = FactorToBase,
            @ExpiryDate         = ExpiryDate,
            @DiscountPercent    = DiscountPercent,
            @Discount           = Discount,
            @OrgPrice           = OrgPrice,
            @CustomDutyRate     = CustomDutyRate,
			@TariffPercent      = TariffPercent,
            --@DutySharePercent   = DutySharePercent,
            @ItemVolume         = ItemVolume,
            --@VolumeSharePercent = VolumeSharePercent,
            @ChangeStatus       = ChangeStatus,
            @PurchaseDetailId   = PurchaseDetailId,
			@ItemType			= ItemType
			--@DefaultCost		=DefaultCost
        FROM @TempTable
        WHERE AutoId = @RowNum;

        SET @ExtTotal= ROUND(@FinalQty*@FinalPrice,2)

        IF @ChangeStatus='I'
        BEGIN
			IF @IsBill = 1 --If bill then insert to source otherwise for PO the source detail is already there 
			BEGIN
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
				   ,[ExpiryDate]
				   ,[DiscountPercent]
				   ,[Discount]
				   ,[OrgPrice]
				   ,[CustomDutyRate]
				   ,[TariffPercent]
				   ,[ItemVolume])
				VALUES
				   (@PurchaseId
				   ,@LineId
				   ,@LineType
				   ,@ItemId
				   ,@AccountId
				   ,@ItemUnitId
				   ,@Unit
				   ,@Notes
				   ,@IsFree
				   ,@IsOut
				   ,@IsCRCG
				   ,@OrdQty0
				   ,@ShipQty
				   ,@BillQty
				   ,@OrdQty1
				   ,@ReceiveQty
				   ,@FinalQty
				   ,@BillPrice
				   ,@BillExtTotal
				   ,@FinalPrice
				   ,@ImportCommission
				   ,@FinalExtTotal
				   ,@FactorToBase
				   ,@ExpiryDate
				   ,@DiscountPercent
				   ,@Discount
				   ,@OrgPrice
				   ,@CustomDutyRate
				   ,@TariffPercent
				   ,@ItemVolume);

				SET @PurchaseDetailId=SCOPE_IDENTITY();
			END

            -- If It's Account Code
			IF @LineType='A'
			BEGIN
				SELECT @IsAccountDebit=IsAccountDebit FROM Account AS C WHERE AccountId=@AccountId

				IF @IsAccountDebit=1
					SET @X = @ExtTotal
				ELSE
					SET @X = -@ExtTotal

				EXEC Fn_Adjust_CrDeAmount @AccountId,@X,@CrDeAmount OUTPUT

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
						,@FinalQty
						,@FinalPrice
						,ABS(@X)
						,@X -- amount
						,@CrDeAmount
						,@PurchaseDetailId)
			END
			ELSE
			BEGIN
				--For NonInventory Logic
				IF @ItemType = 'NonInventory'
				BEGIN
					--For COGS account
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'
					EXEC Fn_Adjust_CrDeAmount @AccountId,@ExtTotal,@CrDeAmount OUTPUT

					INSERT INTO TransactionJournalDetail
							([TxId]
							,[AccountId]
							,[PayeeId]
							,[ItemId]
							,[Amount]
							,[CrDeAmount]
							,[SourceDetailId]
							,[InventoryQty])
					VALUES
							(@TxId
							,@AccountId
							,@PayeeId
							,@ItemId
							,@ExtTotal -- amount
							,@CrDeAmount
							,@PurchaseDetailId
							,@BaseReceiveQty)
				END
				ELSE
				BEGIN
					--Convert Inventory Qty

					--We already convert BaseQty now convert Price
					SET @ConvertedPrice = ROUND(@FinalPrice * @FactorToBase,6)

					--Account = '@COGS'
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'

					INSERT INTO TransactionJournalDetail
							([TxId]
							,[AccountId]
							,[PayeeId]
							,[ItemId]	
							,[Amount]
							,[CrDeAmount]
							,[SourceDetailId]
							,[FactorToBase])
					VALUES
							(@TxId
							,@AccountId
							,@PayeeId
							,@ItemId
							,0 -- amount
							,0 --@CrDeAmt
							,@PurchaseDetailId
							,@FactorToBase)

					--Account = '@INV'
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
							,@BaseReceiveQty
							,@ConvertedPrice
							,@BaseFinalQty	
							,@PurchaseDetailId
							,@FactorToBase
							,@BaseReceiveQty)
				END

				--IF @DefaultCost!=@FinalPrice
				--	UPDATE Item SET DefaultCostB4=@DefaultCost,DefaultCost=@FinalPrice,IsCostChange=1 
				--	WHERE ItemId=@ItemId
			END
        END
        ELSE IF @ChangeStatus='U'
        BEGIN
			IF @IsBill = 1 --If bill then update to source otherwise for PO the source already updated 
			BEGIN
				UPDATE PurchaseDetail
				SET  ItemUnitId        = @ItemUnitId
					,LineId            = @LineId
					,[Unit]            = @Unit
					,Notes             = @Notes
					,IsFree            = @IsFree
					,IsOut             = @IsOut
					,IsCRCG            = @IsCRCG
					,OrdQty0           = @OrdQty0
					,ShipQty           = @ShipQty
					,BillQty           = @BillQty
					,OrdQty1           = @OrdQty1
					,ReceiveQty        = @ReceiveQty
					,FinalQty          = @FinalQty
					,BillPrice         = @BillPrice
					,BillExtTotal      = @BillExtTotal
					,FinalPrice        = @FinalPrice
					,ImportCommission  = @ImportCommission
					,FinalExtTotal     = @FinalExtTotal
					,FactorToBase	   = @FactorToBase
					,ExpiryDate        = @ExpiryDate
					,DiscountPercent   = @DiscountPercent
					,Discount          = @Discount
					,OrgPrice          = @OrgPrice
					,CustomDutyRate    = @CustomDutyRate
					,TariffPercent     = @TariffPercent
					,ItemVolume        = @ItemVolume
				WHERE PurchaseDetailId   = @PurchaseDetailId;
			END

			--if itemcode is changed then calculate old itemcode too
			SELECT @OldItemId=ItemId 
			FROM TransactionJournalDetail 
			WHERE TxId=@TxId AND SourceDetailId=@PurchaseDetailId 
			AND AccountId=(SELECT AccountId FROM @AcctTable WHERE AccountCode='@INV')

			IF @OldItemId!=@ItemId
				INSERT INTO RecalculationLog(ItemId,TxId,TxDate) VALUES(@OldItemId,@TxId,@TxDate)

			-- If It's Account Code
			IF @LineType='A'
			BEGIN
				SELECT @IsAccountDebit=IsAccountDebit FROM Account AS C WHERE AccountId=@AccountId

				IF @IsAccountDebit=1
					SET @X = @ExtTotal
				ELSE
					SET @X = -@ExtTotal

				EXEC Fn_Adjust_CrDeAmount @AccountId,@X,@CrDeAmount OUTPUT

				UPDATE TransactionJournalDetail SET 
				Qty=@FinalQty,
				Price=@FinalPrice,
				BillQty=ABS(@X),
				Amount=@X,
				CrDeAmount=@CrDeAmount,
				ItemId=@ItemId
				WHERE TxId=@TxId AND SourceDetailId=@PurchaseDetailId
			END
			ELSE
			BEGIN
				--For NonInventory Logic
				IF @ItemType = 'NonInventory'
				BEGIN
					--For COGS account
					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'
					EXEC Fn_Adjust_CrDeAmount @AccountId,@ExtTotal,@CrDeAmount OUTPUT

					UPDATE TransactionJournalDetail 
					SET Amount=@ExtTotal,
					CrDeAmount=@CrDeAmount 
					WHERE TxId=@TxId AND SourceDetailId=@PurchaseDetailId
				END
				ELSE
				BEGIN
					--Convert Inventory Qty
					
					--We already convert BaseQty now convert Price
					SET @ConvertedPrice = ROUND(@FinalPrice * @FactorToBase,6)

					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'

					UPDATE TransactionJournalDetail 
					SET ItemId=@ItemId,
					FactorToBase=@FactorToBase 
					WHERE TxId=@TxId AND SourceDetailId=@PurchaseDetailId AND AccountId=@AccountId

					SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@INV'

					UPDATE TransactionJournalDetail 
					SET Qty=@BaseReceiveQty,
					Price=@ConvertedPrice,
					BillQty=@BaseFinalQty,
					ItemId=@ItemId, 
					FactorToBase=@FactorToBase,
					InventoryQty=@BaseReceiveQty
					WHERE TxId=@TxId AND SourceDetailId=@PurchaseDetailId AND AccountId=@AccountId

					--IF @DefaultCost!=@FinalPrice
					--	UPDATE Item SET DefaultCostB4=@DefaultCost,DefaultCost=@FinalPrice,IsCostChange=1 
					--	WHERE ItemId=@ItemId
				END
			END
        END
        ELSE IF @ChangeStatus='D'
        BEGIN
			IF @IsBill = 1 --If bill then delete otherwise for PO the source already updated to NULL
			BEGIN
				DELETE FROM ShipmentAllocation WHERE PurchaseDetailId = @PurchaseDetailId
				DELETE FROM PurchaseDetail WHERE PurchaseDetailId = @PurchaseDetailId
			END

			DELETE FROM TransactionJournalDetail WHERE SourceDetailId=@PurchaseDetailId AND TxId=@TxId
        END

        SET @RowNum += 1 
    END

	--INSERT INTO RecalculationLog(ItemId,TxId,TxDate)
	--SELECT ItemId,@TxId,@TxDate FROM @TempTable WHERE ChangeStatus IS NOT NULL AND LineType='I'

	-- update source table
	DECLARE @FinalTotal DECIMAL(18,2);

	EXEC [Purchase_CalcTotalAndPercent] @PurchaseId,@FinalTotal OUTPUT

	--EXEC [Purchase_CalcFreightDutyOutside] @PurchaseId

	--update @AP account
	SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@AP'
	EXEC Fn_Adjust_CrDeAmount @AccountId,@FinalTotal,@CrDeAmount OUTPUT

	UPDATE TransactionJournalDetail 
	SET Amount=@FinalTotal,CrDeAmount=@CrDeAmount 
	WHERE TxId=@TxId AND AccountId=@AccountId

	DELETE TempPurchase WHERE PayeeId=@PayeeId AND EmpId=@EmpId AND PurchaseId=@PurchaseId

	EXEC [Shipment_Allocation] @PurchaseId,null
	EXEC [Shipment_AllocationInventoryClear] @PurchaseId

	IF @StageId <> 6
		EXEC Recalc_AfterInsert @TxId,@ArrivalDate
END





GO


CREATE PROCEDURE [dbo].[PurchaseOrder_Insert]  
	
    @PurchaseId INT,
	@PayeeId INT,
	@PurchaseDate DATE,
    @ArrivalDate DATE,
	@Notes NVARCHAR(255),
	@EmpId INT,
	@NewPurchaseId INT OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @OldPurchaseId INT = @PurchaseId;
    DECLARE @PurchaseNumber INT = 0;
    DECLARE @StageId INT=1
    DECLARE @TermId INT
	DECLARE @CreatedAt DATETIME = GETUTCDATE()

    DECLARE @FinalTotal DECIMAL(18,2)

    SELECT @TermId=TermId FROM Payee WHERE PayeeId=@PayeeId

	IF @PurchaseId > 0
    BEGIN
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
				,FactorToBase	   = t.FactorToBase
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
               ,[ExpiryDate]
               ,[DiscountPercent]
               ,[Discount]
               ,[OrgPrice]
               ,[CustomDutyRate]
			   ,[TariffPercent]
               ,[ItemVolume])
          SELECT @PurchaseId
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
               ,[DiscountPercent]
               ,[Discount]
               ,[OrgPrice]
               ,[CustomDutyRate]
			   ,[TariffPercent]
               ,[ItemVolume]
           FROM TempPurchase 
           WHERE PayeeId = @PayeeId AND EmpId = @EmpId AND ChangeStatus = 'I';
    END
    ELSE
    BEGIN
        SET @PurchaseNumber = NEXT VALUE FOR dbo.Seq_PurchaseNumber;

        INSERT INTO [dbo].[Purchase]
           ([PurchaseNumber]
           ,[StageId]
           ,[PayeeId]
           ,[PurchaseDate]
           ,[EnterDate]
           ,[ArrivalDate]
           ,[TermId]
           ,[Notes]
           ,[IsLocked]
           ,[IsStartFromPO]
           ,[CreatedAt])
        VALUES
           (@PurchaseNumber
           ,@StageId
           ,@PayeeId
           ,ISNULL(@PurchaseDate,GETDATE())
           ,GETDATE()
           ,@ArrivalDate
           ,@TermId
           ,@Notes
           ,0
           ,1
           ,@CreatedAt)

        SELECT @PurchaseId = SCOPE_IDENTITY();

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
               ,[ExpiryDate]
               ,[DiscountPercent]
               ,[Discount]
               ,[OrgPrice]
               ,[CustomDutyRate]
			   ,[TariffPercent]
               ,[ItemVolume])
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
               ,[DiscountPercent]
               ,[Discount]
               ,[OrgPrice]
               ,[CustomDutyRate]
			   ,[TariffPercent]
               ,[ItemVolume]
	    FROM TempPurchase WHERE EmpId=@EmpId and PayeeId=@PayeeId AND PurchaseId = 0
	    ORDER BY LineId

        --Insert in Tx

        DECLARE @AccountId INT
        DECLARE @TxId BIGINT;
        DECLARE @DocOrder INT;
        DECLARE @DocType NVARCHAR(100) = 'Purchase';
        EXEC [Get_SourceDocOrder] @DocType, @DocOrder OUTPUT;

        INSERT INTO [dbo].[TransactionJournal]
			([TxDate]
			,[TxTime]
			,[SourceDocOrder]
			,[SourceDocType]
			,[SourceDocNumber])
		VALUES
			(@PurchaseDate
			,GETUTCDATE()
			,@DocOrder
			,@DocType
			,@PurchaseNumber)

	    SELECT @TxId = SCOPE_IDENTITY();

        SELECT @AccountId=AccountId FROM Account WHERE AccountCode='@AP'

	    INSERT INTO TransactionJournalDetail
			    ([TxId]
			    ,[AccountId]
			    ,[PayeeId]	
			    ,[Amount]
			    ,[CrDeAmount])
		    VALUES
			    (@TxId
			    ,@AccountId
			    ,@PayeeId
			    ,0
			    ,0)
    END

	EXEC [Purchase_CalcTotalAndPercent] @PurchaseId,@FinalTotal OUTPUT

    SET @NewPurchaseId=@PurchaseId

    DELETE FROM TempPurchase WHERE PayeeId=@PayeeId AND EmpId=@EmpId
END






GO



CREATE PROCEDURE [dbo].[VendorPayment_InsertPayNow] 

	@VendorPaymentId INT,
	@PayeeId INT,
	@PaymentDate DATE,
	@PaymentMethod NVARCHAR(50),
	@FromAccountId INT,
	@ReferenceId NVARCHAR(100),
	@PaymentAmount DECIMAL(18,2),
	@Notes NVARCHAR(255),
	@EmpId INT,
	@NewPaymentId INT OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	
	DECLARE @OldVendorPaymentId INT = @VendorPaymentId;
	DECLARE @VendorPaymentNumber INT;
	DECLARE @TxId BIGINT;
	DECLARE @IsEdit BIT=0
	DECLARE @CrDeAmount DECIMAL(18,2)=0;
	DECLARE @AccountId INT;
	DECLARE @SourceDocType NVARCHAR(100);
	DECLARE @SourceDocOrder INT;
	DECLARE @PaymentType NVARCHAR(100);	
	DECLARE @BankDate DATE
	DECLARE @MailDate DATE;
	DECLARE @PrintDate DATE
	DECLARE @IsReturn1 BIT=0
	DECLARE @ReturnType1 NVARCHAR(50)
	DECLARE @ReturnDate1 DATE
	DECLARE @FeeAccountId1 INT
	DECLARE @FeeAmount1 DECIMAL(18,2)
	DECLARE @IsRedeposit BIT=0
	DECLARE @IsReturn2 BIT=0
	DECLARE @ReturnType2 NVARCHAR(50)
	DECLARE @ReturnDate2 DATE
	DECLARE @FeeAccountId2 INT
	DECLARE @FeeAmount2 DECIMAL(18,2)
	DECLARE @IsLocked BIT=0;
	DECLARE @CreatedAt DATETIME = GETUTCDATE()
	DECLARE @UpdatedAt DATETIME
	
	DECLARE @IsAccountDebit BIT;
	DECLARE @PurchaseId INT;
	DECLARE @PurchaseNumber INT;
	DECLARE @TermId INT;
	DECLARE @TotalAmtApplied DECIMAL(18,2);
	DECLARE @PurchaseDate DATE;
	DECLARE @EnterDate DATE;
	DECLARE @FinalTotal DECIMAL(18,2);

	IF @VendorPaymentId>0
	BEGIN
		SET @IsEdit = 1;
		SET @UpdatedAt = GETUTCDATE();

		SELECT @VendorPaymentNumber=PaymentNumber,
		@PaymentType=PaymentType,
		@IsLocked=IsLocked,
		@MailDate=MailDate,
		@BankDate=BankDate,
		@PrintDate=PrintDate,
		@IsReturn1=IsReturn1,
		@ReturnType1=ReturnType1,
		@ReturnDate1=ReturnDate1,
		@FeeAccountId1=FeeAccountId1,
		@FeeAmount1=FeeAmount1,
		@IsRedeposit=IsRedeposit,
		@IsReturn2=IsReturn2,
		@ReturnType2=ReturnType2,
		@ReturnDate2=ReturnDate2,
		@FeeAccountId2=FeeAccountId2,
		@FeeAmount2=FeeAmount2,
		@CreatedAt=CreatedAt
		FROM VendorPayment 
		WHERE VendorPaymentId=@VendorPaymentId

		SELECT @PurchaseId=PurchaseId FROM PurchaseDetail WHERE VendorPaymentId=@VendorPaymentId
		SELECT @PurchaseNumber=PurchaseNumber,@PurchaseDate=PurchaseDate,@EnterDate=EnterDate FROM Purchase WHERE PurchaseId=@PurchaseId

		DELETE FROM VendorPayment WHERE VendorPaymentId=@VendorPaymentId
	END
	ELSE
	BEGIN
		SET @VendorPaymentNumber = NEXT VALUE FOR dbo.Seq_VendorPaymentNumber;
		SET @PurchaseNumber = NEXT VALUE FOR dbo.Seq_PurchaseNumber;
	END

	IF @PaymentMethod = 'CREDIT CARD'
		SET @PaymentType = 'Credit Card Charge'
	ELSE
		SET @PaymentType = 'Check'
	
	IF @PaymentMethod = 'HANDWRITE CHECK'
		SET @MailDate=@PaymentDate

	SET @SourceDocType = @PaymentType
	EXEC [Get_SourceDocOrder] @SourceDocType,@SourceDocOrder OUTPUT

	SELECT @TermId=TermId FROM Payee WHERE PayeeId=@PayeeId

	---To restrict duplicate payment refnum
	IF @VendorPaymentId = 0 AND @PaymentMethod='CHECK'
		EXEC [Get_CheckNumber] @FromAccountId,@ReferenceId OUTPUT


	INSERT INTO [dbo].[VendorPayment]
			([PaymentNumber]
			,[PaymentType]
			,[PayeeId]
			,[PaymentDate]
			,[PaymentMethod]
			,[ReferenceId]
			,[FromAccountId]
			,[PaymentAmount]
			,[Notes]
			,[IsLocked]
			,[MailDate]
			,[BankDate]
			,[PrintDate]
			,[IsReturn1]
			,[ReturnType1]
			,[ReturnDate1]
			,[FeeAccountId1]
			,[FeeAmount1]
			,[IsRedeposit]
			,[IsReturn2]
			,[ReturnType2]
			,[ReturnDate2]
			,[FeeAccountId2]
			,[FeeAmount2]
			,[CreatedAt]
			,[UpdatedAt])
		VALUES
			(@VendorPaymentNumber
			,@PaymentType
			,@PayeeId
			,@PaymentDate
			,@PaymentMethod
			,@ReferenceId
			,@FromAccountId
			,@PaymentAmount
			,@Notes
			,@IsLocked
			,@MailDate
			,@BankDate
			,@PrintDate
			,@IsReturn1
			,@ReturnType1
			,@ReturnDate1
			,@FeeAccountId1
			,@FeeAmount1
			,@IsRedeposit
			,@IsReturn2
			,@ReturnType2
			,@ReturnDate2
			,@FeeAccountId2
			,@FeeAmount2
			,@CreatedAt
			,@UpdatedAt)

	SELECT @VendorPaymentId = SCOPE_IDENTITY();

	
	INSERT INTO [dbo].[Purchase]
			([PurchaseNumber]
			,[StageId]
			,[PayeeId]
			,[PurchaseDate]
			,[EnterDate]
			,[ArrivalDate]	
			,[TermId]
			,[VendorTotal]
			,[PurchaseTotal]
			,[AmountDue]
			,[PaymentApplied]
			,[Aging]
			,[InvoiceAging]
			,[Notes]
			,[IsLocked]
			,[CreatedAt]
			,[UpdatedAt])
		VALUES
			(@PurchaseNumber
			,6
			,@PayeeId
			,@PaymentDate
			,@PaymentDate
			,@PaymentDate
			,@TermId
			,@PaymentAmount
			,@PaymentAmount
			,0
			,@PaymentAmount
			,-1
			,-1
			,@Notes
			,1
			,@CreatedAt
			,@UpdatedAt)
	
	SELECT @PurchaseId = SCOPE_IDENTITY();

	INSERT INTO [dbo].[PurchaseDetail]
           ([PurchaseId]
           ,[LineId]
           ,[LineType]
           ,[ItemId]
           ,[AccountId]
           ,[ItemUnitId]
           ,[Unit]
           ,[Notes]
           ,[OrdQty0]
           ,[ShipQty]
           ,[BillQty]
           ,[OrdQty1]
           ,[ReceiveQty]
           ,[FinalQty]
           ,[BillPrice]
           ,[BillExtTotal]
           ,[FinalPrice]
           ,[FinalExtTotal]
		   ,[FactorToBase]
           ,[ExpiryDate]
           ,[DiscountPercent]
           ,[Discount]
           ,[OrgPrice]
		   ,[VendorPaymentId])
     SELECT
			@PurchaseId
           ,[LineId]
           ,[LineType]
           ,[ItemId]
           ,[AccountId]
           ,[ItemUnitId]
           ,[Unit]
           ,[Notes]
           ,[OrdQty0]
           ,[ShipQty]
           ,[BillQty]
           ,[OrdQty1]
           ,[ReceiveQty]
           ,[FinalQty]
           ,[BillPrice]
           ,[BillExtTotal]
           ,[FinalPrice]
           ,[FinalExtTotal]
		   ,[FactorToBase]
           ,[ExpiryDate]
           ,[DiscountPercent]
           ,[Discount]
           ,[OrgPrice]
		   ,@VendorPaymentId
	FROM TempPurchase WHERE EmpId=@EmpId and PayeeId=@PayeeId
	AND PurchaseId = CASE WHEN @IsEdit=0 THEN 0 ELSE @OldVendorPaymentId END
	AND (ChangeStatus!='D' OR ChangeStatus IS NULL)
	ORDER BY LineId

	EXEC [Purchase_CalcTotalAndPercent] @PurchaseId,@FinalTotal OUTPUT

	--Insert into TransactionJournal

	CREATE TABLE #PurTxDetail
	(
		TxDetailId int IDENTITY(1,1)
		,TxId BIGINT
		,AccountId INT
		,PayeeId INT
		,ItemId INT
		,Qty DECIMAL(18,2)
		,Price DECIMAL(18,2)
		,BillQty DECIMAL(18,2)
		,FactorToBase DECIMAL(18,6)
		,InventoryQty DECIMAL(18,2)
		,Amount DECIMAL(18,2)
		,CrDeAmount DECIMAL(18,2)
		,SrcDetailId INT
	)
	 
	INSERT INTO [dbo].[TransactionJournal]
        ([TxDate]
		,[TxTime]
        ,[SourceDocOrder]
        ,[SourceDocType]
        ,[SourceDocNumber]
        ,[Notes])
	VALUES
        (@PaymentDate,
		GETUTCDATE(),
		@SourceDocOrder,
		@SourceDocType,
		@VendorPaymentNumber,
		@Notes)

	SELECT @TxId = SCOPE_IDENTITY();

	DECLARE @X DECIMAL(18,2)
	SELECT @IsAccountDebit=IsAccountDebit FROM Account AS a WHERE AccountId=@FromAccountId

	IF @IsAccountDebit=1
		SET @X = -@PaymentAmount
	ELSE
		SET @X = @PaymentAmount

	EXEC Fn_Adjust_CrDeAmount @FromAccountId,@X,@CrDeAmount OUTPUT
	
	INSERT INTO #PurTxDetail
			([TxId]
			,[AccountId]
			,[PayeeId]
			,[Amount]
			,[CrDeAmount])
		VALUES
			(@TxId
			,@FromAccountId
			,@PayeeId	
			,@X
			,@CrDeAmount)

	
	--for multiple product purchase
	DECLARE @LineType NVARCHAR(1)
	DECLARE @MyItemId INT
	DECLARE @MyAccountId INT
	DECLARE @MyItemType NVARCHAR(50)
	DECLARE @FinalQty DECIMAL(18,2)
	DECLARE @BaseReceiveQty DECIMAL(18,6)
	DECLARE @BaseFinalQty DECIMAL(18,6)
	DECLARE @MyFinalPrice DECIMAL(18,2)
	DECLARE @FactorToBase DECIMAL(18,6)
	DECLARE @SDId INT

	DECLARE @COGSExtTotal DECIMAL(18,2)
	DECLARE @ExpenseExtTotal DECIMAL(18,2)
	DECLARE @InventoryExtTotal DECIMAL(18,2)
	DECLARE @ConvertedPrice DECIMAL(18,6)

	DECLARE @AcctTable AS Table(
		Id INT IDENTITY(1,1),
		AccountCode NVARCHAR(50),
		AccountId INT
	)

	INSERT INTO @AcctTable(AccountCode) VALUES('@COGS')
	INSERT INTO @AcctTable(AccountCode) VALUES('@INV')

	DECLARE @MyTable TABLE (
		[AutoId] [int] IDENTITY(1,1) NOT NULL,
		[LineType] NVARCHAR(1),
		[ItemId] INT NULL,
		[AccountId] INT NULL,
		[ItemType] [nvarchar](50) NULL,
		[FinalQty] DECIMAL(18,2) NULL,
		[BaseReceiveQty] DECIMAL(18,6) NULL,
		[BaseFinalQty] DECIMAL(18,6) NULL,
		[FinalPrice] DECIMAL(18,4) NULL,
		[FactorToBase] DECIMAL(18,6),
		[SDId] INT
	)

	INSERT INTO @MyTable
	SELECT pd.LineType
		,pd.ItemId
		,pd.AccountId
		,i.ItemType
		,FinalQty
		,BaseReceiveQty
		,BaseFinalQty
		,ROUND(FinalPrice,2)
		,pd.FactorToBase
		,PurchaseDetailId
	FROM PurchaseDetail as pd LEFT JOIN Item as i on pd.ItemId=i.ItemId
	WHERE PurchaseId=@PurchaseId ORDER BY PurchaseDetailId
	
	DECLARE @RowNum INT=1
	DECLARE @MaxRow INT
	
	SELECT @MaxRow=COUNT(AutoId) FROM @MyTable

	WHILE @RowNum <= @MaxRow
	BEGIN
		SELECT
			@LineType=LineType,
			@MyItemId=ItemId,
			@MyAccountId=AccountId,
			@MyItemType=ItemType,
			@FinalQty=FinalQty,
			@BaseReceiveQty=BaseReceiveQty,
			@BaseFinalQty=BaseFinalQty,
			@MyFinalPrice=FinalPrice,
			@FactorToBase=FactorToBase,
			@SDId=SDId
		FROM @MyTable WHERE AutoId=@RowNum

		-- If It's Account Code
		IF @LineType='A'
		BEGIN
			SET @ExpenseExtTotal = ROUND(@FinalQty*@MyFinalPrice,2) 
			SELECT @IsAccountDebit=IsAccountDebit FROM Account AS C WHERE AccountId=@MyAccountId

			IF @IsAccountDebit=1
				SET @X = @ExpenseExtTotal
			ELSE
				SET @X = -@ExpenseExtTotal

			EXEC Fn_Adjust_CrDeAmount @MyAccountId,@X,@CrDeAmount OUTPUT

			INSERT INTO #PurTxDetail
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
					,@MyAccountId
					,@PayeeId
					,@BaseFinalQty
					,@MyFinalPrice
					,ABS(@X)
					,@X -- amount
					,@CrDeAmount
					,@SDId)
		END
		ELSE
		BEGIN
			--For NonInventory Logic
			IF @MyItemType = 'NonInventory'
			BEGIN
				--For COGS account
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'
				SET @COGSExtTotal= ROUND(@FinalQty*@MyFinalPrice,2)

				EXEC Fn_Adjust_CrDeAmount @AccountId,@COGSExtTotal,@CrDeAmount OUTPUT

				INSERT INTO #PurTxDetail
						([TxId]
						,[AccountId]
						,[PayeeId]
						,[ItemId]
						,[Amount]
						,[CrDeAmount]
						,[SrcDetailId])
				VALUES
						(@TxId
						,@AccountId
						,@PayeeId
						,@MyItemId
						,@COGSExtTotal -- amount
						,@CrDeAmount
						,@SDId)
			END
			ELSE
			BEGIN
				--Convert Inventory Qty
				--We already convert BaseQty now convert Price
				SET @ConvertedPrice = ROUND(@MyFinalPrice * @FactorToBase,2)
				
				--SET @AccountCode = '@COGS'
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'

				INSERT INTO #PurTxDetail
						([TxId]
						,[AccountId]
						,[PayeeId]
						,[ItemId]	
						,[Amount]
						,[CrDeAmount]
						,[SrcDetailId]
						,[FactorToBase])
				VALUES
						(@TxId
						,@AccountId
						,@PayeeId
						,@MyItemId
						,0 -- amount
						,0 --@CrDeAmt
						,@SDId
						,@FactorToBase)

				--SET @AccountCode = '@INV'
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@INV'

				INSERT INTO #PurTxDetail
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
						,@MyItemId
						,@BaseReceiveQty
						,@ConvertedPrice
						,@BaseFinalQty	
						,@SDId
						,@FactorToBase
						,@BaseFinalQty)
			END
		END

		SET @RowNum += 1
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
	FROM #PurTxDetail AS p
	ORDER BY TxDetailId

	DELETE FROM TempPurchase WHERE PayeeId=@PayeeId AND EmpId=@EmpId 

	-- call RecalcQAV after insert
	EXEC Recalc_AfterInsert @TxId,@PaymentDate

	SET @NewPaymentId = @VendorPaymentId;

END






GO


