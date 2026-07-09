
-- 2026-07-07 (Effort-B): @INV rows written here are ENTERED basis (was base/converted). Single @INV path
--   (loop @INV insert):
--     Price             = @MyFinalPrice  -- drop old (@MyFinalPrice x @FactorToBase); goods price is entered.
--     BillQty           = @FinalQty      -- entered value (was @BaseFinalQty).
--     FactorToBase slot = @ReceiveQty    -- repurposed ratio -> entered physical qty (plumbed via @MyTable).
--   Qty stays @BaseReceiveQty (base physical). Landed NOT added here. Fresh insert (no survivor rows); does not
--   call InventoryClear -- if this pay-now purchase is later billed, the anchor (Option B) normalizes its @INV
--   rows. Deploys as ONE batch with InventoryClear + Purchase_Insert + Purchase_PartialUpdate.

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B3-VendorPayment_InsertPayNow: 4-decimal pricing §B Phase-1 (storage/type widen, inert).
--   Widen @MyFinalPrice (entered goods price) 2dp -> 4dp and the journal temp #PurTxDetail.Price 2dp -> 6dp
--   (match TransactionJournalDetail.Price). Inert today: @MyFinalPrice is capped <=2dp by the ROUND(FinalPrice,2)
--   at its load (left unchanged for Phase-2), and #PurTxDetail.Price is fed only from it / @ConvertedPrice.
--   Money ROUND(qty*price,2) amounts unchanged.
CREATE OR ALTER PROCEDURE [dbo].[VendorPayment_InsertPayNow]
	@VendorPaymentId	INT,
	@PayeeId			INT,
	@PaymentDate		DATE,
	@PaymentMethod		NVARCHAR(50),
	@FromAccountId		INT,
	@ReferenceId		NVARCHAR(100),
	@PaymentAmount		DECIMAL(18,2),
	@Notes				NVARCHAR(255),
	@EmpId				INT,
	@NewPaymentId		INT OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Insert statements for procedure here

	DECLARE @OldVendorPaymentId		INT = @VendorPaymentId;
	DECLARE @VendorPaymentNumber	INT;
	DECLARE @TxId					BIGINT;
	DECLARE @IsEdit					BIT = 0;
	DECLARE @CrDeAmount				DECIMAL(18,2) = 0;
	DECLARE @AccountId				INT;
	DECLARE @SourceDocType			NVARCHAR(100);
	DECLARE @SourceDocOrder			INT;
	DECLARE @PaymentType			NVARCHAR(100);
	DECLARE @BankDate				DATE;
	DECLARE @MailDate				DATE;
	DECLARE @PrintDate				DATE;
	DECLARE @IsReturn1				BIT = 0;
	DECLARE @ReturnType1			NVARCHAR(50);
	DECLARE @ReturnDate1			DATE;
	DECLARE @FeeAccountId1			INT;
	DECLARE @FeeAmount1				DECIMAL(18,2);
	DECLARE @IsRedeposit			BIT = 0;
	DECLARE @IsReturn2				BIT = 0;
	DECLARE @ReturnType2			NVARCHAR(50);
	DECLARE @ReturnDate2			DATE;
	DECLARE @FeeAccountId2			INT;
	DECLARE @FeeAmount2				DECIMAL(18,2);
	DECLARE @IsLocked				BIT = 0;
	DECLARE @CreatedAt				DATETIME = GETUTCDATE();
	DECLARE @UpdatedAt				DATETIME;

	DECLARE @IsAccountDebit			BIT;
	DECLARE @PurchaseId				INT;
	DECLARE @PurchaseNumber			INT;
	DECLARE @TermId					INT;
	DECLARE @TotalAmtApplied		DECIMAL(18,2);
	DECLARE @PurchaseDate			DATE;
	DECLARE @EnterDate				DATE;
	DECLARE @FinalTotal				DECIMAL(18,2);
	DECLARE @BillTotal				DECIMAL(18,2);

	IF @VendorPaymentId > 0
	BEGIN
		SET @IsEdit = 1;
		SET @UpdatedAt = GETUTCDATE();

		SELECT
			@VendorPaymentNumber	= PaymentNumber,
			@PaymentType			= PaymentType,
			@IsLocked				= IsLocked,
			@MailDate				= MailDate,
			@BankDate				= BankDate,
			@PrintDate				= PrintDate,
			@IsReturn1				= IsReturn1,
			@ReturnType1			= ReturnType1,
			@ReturnDate1			= ReturnDate1,
			@FeeAccountId1			= FeeAccountId1,
			@FeeAmount1				= FeeAmount1,
			@IsRedeposit			= IsRedeposit,
			@IsReturn2				= IsReturn2,
			@ReturnType2			= ReturnType2,
			@ReturnDate2			= ReturnDate2,
			@FeeAccountId2			= FeeAccountId2,
			@FeeAmount2				= FeeAmount2,
			@CreatedAt				= CreatedAt
		FROM VendorPayment
		WHERE VendorPaymentId = @VendorPaymentId;

		SELECT @PurchaseId = PurchaseId
		FROM PurchaseDetail
		WHERE VendorPaymentId = @VendorPaymentId;

		SELECT
			@PurchaseNumber	= PurchaseNumber,
			@PurchaseDate	= PurchaseDate,
			@EnterDate		= EnterDate
		FROM Purchase
		WHERE PurchaseId = @PurchaseId;

		DELETE FROM VendorPayment WHERE VendorPaymentId = @VendorPaymentId;
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
		SET @MailDate = @PaymentDate

	SET @SourceDocType = @PaymentType
	EXEC [Get_SourceDocOrder] @SourceDocType, @SourceDocOrder OUTPUT

	SELECT @TermId = TermId FROM Payee WHERE PayeeId = @PayeeId

	---To restrict duplicate payment refnum
	IF @VendorPaymentId = 0 AND @PaymentMethod = 'CHECK'
		EXEC [Get_CheckNumber] @FromAccountId, @ReferenceId OUTPUT


	INSERT INTO [dbo].[VendorPayment]
	(
		[PaymentNumber],
		[PaymentType],
		[PayeeId],
		[PaymentDate],
		[PaymentMethod],
		[ReferenceId],
		[FromAccountId],
		[PaymentAmount],
		[Notes],
		[IsLocked],
		[MailDate],
		[BankDate],
		[PrintDate],
		[IsReturn1],
		[ReturnType1],
		[ReturnDate1],
		[FeeAccountId1],
		[FeeAmount1],
		[IsRedeposit],
		[IsReturn2],
		[ReturnType2],
		[ReturnDate2],
		[FeeAccountId2],
		[FeeAmount2],
		[CreatedAt],
		[UpdatedAt]
	)
	VALUES
	(
		@VendorPaymentNumber,
		@PaymentType,
		@PayeeId,
		@PaymentDate,
		@PaymentMethod,
		@ReferenceId,
		@FromAccountId,
		@PaymentAmount,
		@Notes,
		@IsLocked,
		@MailDate,
		@BankDate,
		@PrintDate,
		@IsReturn1,
		@ReturnType1,
		@ReturnDate1,
		@FeeAccountId1,
		@FeeAmount1,
		@IsRedeposit,
		@IsReturn2,
		@ReturnType2,
		@ReturnDate2,
		@FeeAccountId2,
		@FeeAmount2,
		@CreatedAt,
		@UpdatedAt
	);

	SELECT @VendorPaymentId = SCOPE_IDENTITY();


	INSERT INTO [dbo].[Purchase]
	(
		[PurchaseNumber],
		[StageId],
		[PayeeId],
		[PurchaseDate],
		[EnterDate],
		[ArrivalDate],
		[TermId],
		[VendorTotal],
		[PurchaseTotal],
		[AmountDue],
		[PaymentApplied],
		[Aging],
		[InvoiceAging],
		[Notes],
		[IsLocked],
		[CreatedAt],
		[UpdatedAt]
	)
	VALUES
	(
		@PurchaseNumber,
		6,
		@PayeeId,
		@PaymentDate,
		@PaymentDate,
		@PaymentDate,
		@TermId,
		@PaymentAmount,
		@PaymentAmount,
		0,
		@PaymentAmount,
		-1,
		-1,
		@Notes,
		1,
		@CreatedAt,
		@UpdatedAt
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
		[OrdQty0],
		[ShipQty],
		[BillQty],
		[OrdQty1],
		[ReceiveQty],
		[FinalQty],
		[BillPrice],
		[BillExtTotal],
		[FinalPrice],
		[FinalExtTotal],
		[FactorToBase],
		[ExpiryDate],
		[DiscountPercent],
		[Discount],
		[OrgPrice],
		[VendorPaymentId]
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
		[OrdQty0],
		[ShipQty],
		[BillQty],
		[OrdQty1],
		[ReceiveQty],
		[FinalQty],
		[BillPrice],
		[BillExtTotal],
		[FinalPrice],
		[FinalExtTotal],
		[FactorToBase],
		[ExpiryDate],
		[DiscountPercent],
		[Discount],
		[OrgPrice],
		@VendorPaymentId
	FROM TempPurchase
	WHERE EmpId = @EmpId
		AND PayeeId = @PayeeId
		AND PurchaseId = CASE WHEN @IsEdit = 0 THEN 0 ELSE @OldVendorPaymentId END
		AND (ChangeStatus != 'D' OR ChangeStatus IS NULL)
	ORDER BY LineId

	-- Purchase_CalcTotalAndPercent is now narrowed for post-commit follow-up.
	-- Preserve the original core ownership here so this purchase-posting path
	-- still refreshes header totals and base quantities before journal build.
	-- Legacy helper-owned responsibilities restored locally here:
	--   1. VendorTotal / PurchaseTotal
	--   2. LineId renumber
	--   3. BaseReceiveQty / BaseFinalQty
	-- This keeps VendorPayment_InsertPayNow compatible with the narrowed helper.
	SELECT
		@BillTotal	= ISNULL(SUM(ROUND(BillQty * BillPrice, 2)), 0),
		@FinalTotal	= ISNULL(SUM(ROUND(FinalQty * FinalPrice, 2)), 0)
	FROM PurchaseDetail
	WHERE PurchaseId = @PurchaseId

	;WITH cte AS
	(
		SELECT *,
			ROW_NUMBER() OVER (ORDER BY LineId) AS NewLineId
		FROM PurchaseDetail
		WHERE PurchaseId = @PurchaseId
	)
	UPDATE cte
	SET
		LineId			= NewLineId;

	-- 2026-07-05 (Phase B): base qty moved out of the CTE to a dedicated producer below.
	-- ITEM lines -> ItemUnitId -> ItemUnit (Fn_QtyToBase). ACCOUNT lines have no ItemUnitId but
	-- CONSUME @BaseFinalQty (the account journal row's Qty, loop below), so LEFT JOIN + CASE fallback
	-- keeps them on the snapshot factor (account FactorToBase=1 => base=FinalQty, unchanged). The ELSE
	-- branch is the OLD formula verbatim.
	-- 2026-07-07 (Effort-B) SUPERSEDES the old "@FactorToBase snapshot stays for the @INV price" note: the @INV
	-- Price now drops x @FactorToBase (entered @MyFinalPrice); @FactorToBase remains only for the @COGS row.
	-- Prior (in CTE):
	--	BaseReceiveQty	= ROUND(ReceiveQty / FactorToBase, 6),
	--	BaseFinalQty	= ROUND(FinalQty / FactorToBase, 6)
	UPDATE pd
	SET
		pd.BaseReceiveQty = CASE WHEN iu.ItemUnitId IS NOT NULL
		                         THEN dbo.Fn_QtyToBase(pd.ReceiveQty, iu.MultipleToBase, iu.FactorToBase)
		                         ELSE ROUND(pd.ReceiveQty / NULLIF(pd.FactorToBase, 0), 6) END,
		pd.BaseFinalQty   = CASE WHEN iu.ItemUnitId IS NOT NULL
		                         THEN dbo.Fn_QtyToBase(pd.FinalQty, iu.MultipleToBase, iu.FactorToBase)
		                         ELSE ROUND(pd.FinalQty / NULLIF(pd.FactorToBase, 0), 6) END
	FROM PurchaseDetail pd
	LEFT JOIN ItemUnit iu ON iu.ItemUnitId = pd.ItemUnitId
	WHERE pd.PurchaseId = @PurchaseId;

	UPDATE Purchase
	SET
		VendorTotal		= @BillTotal,
		PurchaseTotal	= @FinalTotal,
		UpdatedAt		= GETUTCDATE()
	WHERE PurchaseId = @PurchaseId

	EXEC [Purchase_CalcTotalAndPercent] @PurchaseId, @FinalTotal OUTPUT


	--Insert into TransactionJournal

	CREATE TABLE #PurTxDetail
	(
		TxDetailId		INT IDENTITY(1,1),
		TxId			BIGINT,
		AccountId		INT,
		PayeeId			INT,
		ItemId			INT,
		Qty				DECIMAL(18,2),
		-- 4dp widen (journal temp price -> 6dp to match TransactionJournalDetail.Price): was DECIMAL(18,2)
		Price			DECIMAL(18,6),
		BillQty			DECIMAL(18,2),
		FactorToBase	DECIMAL(18,6),
		Amount			DECIMAL(18,2),
		CrDeAmount		DECIMAL(18,2),
		SrcDetailId		INT
	)


	INSERT INTO [dbo].[TransactionJournal]
	(
		[TxDate],
		[TxTime],
		[SourceDocOrder],
		[SourceDocType],
		[SourceDocNumber],
		[Notes]
	)
	VALUES
	(
		@PaymentDate,
		GETUTCDATE(),
		@SourceDocOrder,
		@SourceDocType,
		@VendorPaymentNumber,
		@Notes
	);

	SELECT @TxId = SCOPE_IDENTITY();


	DECLARE @X DECIMAL(18,2)
	SELECT @IsAccountDebit = IsAccountDebit FROM Account AS a WHERE AccountId = @FromAccountId

	IF @IsAccountDebit = 1
		SET @X = -@PaymentAmount
	ELSE
		SET @X = @PaymentAmount

	EXEC Fn_Adjust_CrDeAmount @FromAccountId, @X, @CrDeAmount OUTPUT


	INSERT INTO #PurTxDetail
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
		@FromAccountId,
		@PayeeId,
		@X,
		@CrDeAmount
	);


	--for multiple product purchase
	DECLARE @LineType			NVARCHAR(1)
	DECLARE @MyItemId			INT
	DECLARE @MyAccountId		INT
	DECLARE @MyItemType			NVARCHAR(50)
	DECLARE @FinalQty			DECIMAL(18,2)
	DECLARE @ReceiveQty			DECIMAL(18,2)	-- 2026-07-07 Effort-B: entered physical qty -> @INV FactorToBase slot
	DECLARE @BaseReceiveQty		DECIMAL(18,6)
	DECLARE @BaseFinalQty		DECIMAL(18,6)
	-- 4dp widen (entered goods price): was DECIMAL(18,2)
	DECLARE @MyFinalPrice		DECIMAL(18,4)
	DECLARE @FactorToBase		DECIMAL(18,6)
	DECLARE @SDId				INT

	DECLARE @COGSExtTotal		DECIMAL(18,2)
	DECLARE @ExpenseExtTotal	DECIMAL(18,2)
	DECLARE @InventoryExtTotal	DECIMAL(18,2)
	DECLARE @ConvertedPrice		DECIMAL(18,6)

	DECLARE @AcctTable AS TABLE
	(
		Id			INT IDENTITY(1,1),
		AccountCode	NVARCHAR(50),
		AccountId	INT
	)

	INSERT INTO @AcctTable (AccountCode) VALUES ('@COGS')
	INSERT INTO @AcctTable (AccountCode) VALUES ('@INV')

	DECLARE @MyTable TABLE
	(
		[AutoId]			INT IDENTITY(1,1) NOT NULL,
		[LineType]			NVARCHAR(1),
		[ItemId]			INT NULL,
		[AccountId]			INT NULL,
		[ItemType]			NVARCHAR(50) NULL,
		[FinalQty]			DECIMAL(18,2) NULL,
		[BaseReceiveQty]	DECIMAL(18,6) NULL,
		[BaseFinalQty]		DECIMAL(18,6) NULL,
		[FinalPrice]		DECIMAL(18,4) NULL,
		[FactorToBase]		DECIMAL(18,6),
		[SDId]				INT,
		-- 2026-07-07 Effort-B: entered physical qty, plumbed for the @INV FactorToBase slot
		[ReceiveQty]		DECIMAL(18,2) NULL
	)

	-- 2026-07-07 Effort-B: explicit column list added (was none) so plumbing ReceiveQty cannot shift
	-- the decimal columns by ordinal. ReceiveQty appended last (maps to @MyTable.[ReceiveQty]).
	INSERT INTO @MyTable
		(LineType, ItemId, AccountId, ItemType, FinalQty, BaseReceiveQty, BaseFinalQty,
		 FinalPrice, FactorToBase, SDId, ReceiveQty)
	SELECT
		pd.LineType,
		pd.ItemId,
		pd.AccountId,
		i.ItemType,
		FinalQty,
		BaseReceiveQty,
		BaseFinalQty,
		ROUND(FinalPrice, 2),
		pd.FactorToBase,
		PurchaseDetailId,
		pd.ReceiveQty
	FROM PurchaseDetail AS pd
		LEFT JOIN Item AS i ON pd.ItemId = i.ItemId
	WHERE PurchaseId = @PurchaseId
	ORDER BY PurchaseDetailId


	DECLARE @RowNum INT = 1
	DECLARE @MaxRow INT

	SELECT @MaxRow = COUNT(AutoId) FROM @MyTable

	WHILE @RowNum <= @MaxRow
	BEGIN
		SELECT
			@LineType		= LineType,
			@MyItemId		= ItemId,
			@MyAccountId	= AccountId,
			@MyItemType		= ItemType,
			@FinalQty		= FinalQty,
			@ReceiveQty		= ReceiveQty,
			@BaseReceiveQty	= BaseReceiveQty,
			@BaseFinalQty	= BaseFinalQty,
			@MyFinalPrice	= FinalPrice,
			@FactorToBase	= FactorToBase,
			@SDId			= SDId
		FROM @MyTable WHERE AutoId = @RowNum

		-- If It's Account Code
		IF @LineType = 'A'
		BEGIN
			SET @ExpenseExtTotal = ROUND(@FinalQty * @MyFinalPrice, 2)
			SELECT @IsAccountDebit = IsAccountDebit FROM Account AS C WHERE AccountId = @MyAccountId

			IF @IsAccountDebit = 1
				SET @X = @ExpenseExtTotal
			ELSE
				SET @X = -@ExpenseExtTotal

			EXEC Fn_Adjust_CrDeAmount @MyAccountId, @X, @CrDeAmount OUTPUT

			INSERT INTO #PurTxDetail
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
				@MyAccountId,
				@PayeeId,
				@BaseFinalQty,
				@MyFinalPrice,
				ABS(@X),
				@X, -- amount
				@CrDeAmount,
				@SDId
			);
		END
		ELSE
		BEGIN
			--For NonInventory Logic
			IF @MyItemType = 'NonInventory'
			BEGIN
				--For COGS account
				SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@COGS'
				SET @COGSExtTotal = ROUND(@FinalQty * @MyFinalPrice, 2)

				EXEC Fn_Adjust_CrDeAmount @AccountId, @COGSExtTotal, @CrDeAmount OUTPUT

				INSERT INTO #PurTxDetail
				(
					[TxId],
					[AccountId],
					[PayeeId],
					[ItemId],
					[Amount],
					[CrDeAmount],
					[SrcDetailId]
				)
				VALUES
				(
					@TxId,
					@AccountId,
					@PayeeId,
					@MyItemId,
					@COGSExtTotal, -- amount
					@CrDeAmount,
					@SDId
				);
			END
			ELSE
			BEGIN
				--Convert Inventory Qty
				--We already convert BaseQty now convert Price
				SET @ConvertedPrice = @MyFinalPrice  -- 2026-07-07 Effort-B: entered goods price; was ROUND(@MyFinalPrice * @FactorToBase, 2) (x @FactorToBase dropped; landed added at billing)

				--SET @AccountCode = '@COGS'
				SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@COGS'

				INSERT INTO #PurTxDetail
				(
					[TxId],
					[AccountId],
					[PayeeId],
					[ItemId],
					[Amount],
					[CrDeAmount],
					[SrcDetailId],
					[FactorToBase]
				)
				VALUES
				(
					@TxId,
					@AccountId,
					@PayeeId,
					@MyItemId,
					0, -- amount
					0, --@CrDeAmt
					@SDId,
					@FactorToBase
				);

				--SET @AccountCode = '@INV'
				SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@INV'

				INSERT INTO #PurTxDetail
				(
					[TxId],
					[AccountId],
					[PayeeId],
					[ItemId],
					[Qty],
					[Price],
					[BillQty],
					[SrcDetailId],
					[FactorToBase]
				)
				VALUES
				(
					@TxId,
					@AccountId,
					@PayeeId,
					@MyItemId,
					@BaseReceiveQty,
					@ConvertedPrice,
					-- 2026-07-07 Effort-B: BillQty base->entered.  OLD: @BaseFinalQty,
					@FinalQty,
					@SDId,
					-- 2026-07-07 Effort-B: FactorToBase slot ratio->EntQty.  OLD: @FactorToBase
					@ReceiveQty
				);
			END
		END

		SET @RowNum += 1
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
		[FactorToBase]
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
		[FactorToBase]
	FROM #PurTxDetail AS p
	ORDER BY TxDetailId


	DELETE FROM TempPurchase WHERE PayeeId = @PayeeId AND EmpId = @EmpId

	-- call RecalcQAV after insert
	EXEC Recalc_AfterInsert @TxId, @PaymentDate

	SET @NewPaymentId = @VendorPaymentId;

END
GO



