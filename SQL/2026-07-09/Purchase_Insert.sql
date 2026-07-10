

-- Purchase_Insert codex candidate
-- Baseline: live dbo.Purchase_Insert from KLS_Latest
--
-- Summary:
--   Goal: keep the same posting result as baseline, while making temp-cart-owned
--   LineId and journal-driving values explicit and shortening row-by-row work
--   inside the protected posting section.
--
-- Improvements:
--   1. XACT_ABORT + TRY/CATCH transaction wrapper
--   2. Checkout-group applock to reject concurrent/double-submit inserts
--   3. TempPurchase.LineId is trusted directly as the canonical cart order
--   4. Core totals and base quantities stay inline before journal build
--   5. Journal generation is set-based, but still preserves baseline per-line
--      row grouping and inventory @COGS/@INV adjacency
--   6. Recalc enqueue happens immediately after commit; broader helper work stays after commit
--
-- 2026-07-07 (Effort-B): @INV row is ENTERED basis (was base/converted). Section-11 @INV insert:
--   Price       = ROUND(pd.FinalPrice,2)  -- drop the old (x pd.FactorToBase); goods price is entered.
--   BillQty     = pd.FinalQty             -- entered value (was pd.BaseFinalQty).
--   FactorToBase slot = pd.ReceiveQty     -- repurposed ratio -> entered physical qty (audit, no consumer).
--   Qty stays pd.BaseReceiveQty (base physical). Landed is NOT added here (added at billing by
--   Shipment_AllocationInventoryClear). This SUPERSEDES the old "QTY ONLY / price-threading deferred"
--   guidance -- price is no longer deferred. Deploys as ONE batch with InventoryClear +
--   Purchase_PartialUpdate + VendorPayment_InsertPayNow.

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B-Phase2-Slice2-Purchase_Insert: Class-A pass-through ROUND flip (unconditional, inert).
--   Flip the two journal-Price writes ROUND(pd.FinalPrice,2) -> ROUND(pd.FinalPrice,4). FinalPrice is the
--   entered goods price (<=2dp today) so this is byte-identical now; carries 4dp once 4dp input exists.
--   All money ROUND(qty*price,2) amounts are LEFT at 2dp.
CREATE OR ALTER PROCEDURE [dbo].[Purchase_Insert]
	
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
	-- Section 1: initialize procedure state and working variables.
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	SET @ArrivalDate = ISNULL(@ArrivalDate,GETDATE())

	-- Section 2: validate header-level business rules before posting.
	IF EXISTS (SELECT 1 FROM Purchase WHERE PayeeId = @PayeeId
      AND VendorDocNumber = @VendorDocNumber
      AND PurchaseId != @PurchaseId
	)
	BEGIN
		RAISERROR('Vendor DocNum already exists.', 16, 1);
		RETURN;
	END

	-- Section 3: resolve the standard posting accounts used by the purchase journal.
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
	DECLARE @LockResult INT
	DECLARE @LockResource NVARCHAR(200)
	DECLARE @BillTotal DECIMAL(18,2);
	DECLARE @FinalTotal DECIMAL(18,2);
	DECLARE @CreatedAt DATETIME = GETUTCDATE()

	DECLARE @DocOrder INT;
    DECLARE @DocType NVARCHAR(100) = 'Purchase';
    EXEC [Get_SourceDocOrder] @DocType, @DocOrder OUTPUT;

	SELECT @TermId=TermId FROM Payee WHERE PayeeId=@PayeeId

	IF @TermId IS NULL
	BEGIN
		RAISERROR('Payee not found for Purchase_Insert.', 16, 1);
		RETURN;
	END

	-- Section 4: build checkout-group lock identity and validate payee term.
	SET @LockResource =
		'Purchase_Insert_'
		+ CONVERT(NVARCHAR(20), @EmpId) + '_'
		+ CONVERT(NVARCHAR(20), @PayeeId) + '_'
		+ ISNULL(@VendorDocNumber, 'NULL') + '_'
		+ ISNULL(@ContainerNumber, 'NULL');

	BEGIN TRY
		-- Section 5: start the protected posting transaction.
		BEGIN TRANSACTION;

		EXEC @LockResult = sp_getapplock
			@Resource = @LockResource,
			@LockMode = 'Exclusive',
			@LockOwner = 'Transaction',
			@LockTimeout = 0;

		IF @LockResult < 0
		BEGIN
			RAISERROR('This purchase checkout group is already being posted.', 16, 1);
			RETURN;
		END

		-- Section 6: create the Purchase header.
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

		IF @PurchaseId IS NULL
		BEGIN
			RAISERROR('Purchase header insert failed.', 16, 1);
			RETURN;
		END

		-- Section 7: insert PurchaseDetail from TempPurchase in current temp-cart order.
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

		IF @@ROWCOUNT = 0
		BEGIN
			RAISERROR('No detail rows inserted - TempPurchase may have been cleared.', 16, 1);
			RETURN;
		END

		-- Section 8: keep the journal-driving subset inline.
		-- Original flow called Purchase_CalcTotalAndPercent here inside the transaction.
		-- For the refactor, keep only the journal-driving subset inline:
		-- 1. core totals needed for the @AP row
		-- 2. base quantities needed for @INV rows
		-- TempPurchase.LineId is now the canonical cart order. The TempPurchase
		-- triggers keep it correct, so Purchase_Insert should trust that order
		-- instead of rebuilding LineId here.
		SELECT
			@BillTotal = ISNULL(SUM(ROUND(BillQty * BillPrice, 2)), 0),
			@FinalTotal = ISNULL(SUM(ROUND(FinalQty * FinalPrice, 2)), 0)
		FROM PurchaseDetail
		WHERE PurchaseId = @PurchaseId;

		-- 2026-07-05 (Phase B): base qty derives from the line's ItemUnitId -> ItemUnit
		-- (single source of truth): BaseQty = qty * MultipleToBase / FactorToBase via
		-- dbo.Fn_QtyToBase (inlined). Immutable ratios => the join is authoritative, so the
		-- pd.FactorToBase snapshot read is retired here. INNER JOIN = item lines only; account
		-- lines (LineType='A', no ItemUnitId) drop out -> base qty untouched (they feed no @INV
		-- row; @INV in Section 11 filters LineType<>'A'). Identity today (all MultipleToBase=1
		-- => qty/factor).
		-- 2026-07-07 (Effort-B) SUPERSEDES the old note here ("QTY ONLY: the Section-11 @INV Price still
		-- reads pd.FactorToBase; when combine-up lands it must become FinalPrice * factor / multiple").
		-- The Section-11 @INV Price now DROPS x pd.FactorToBase (entered FinalPrice); BillQty -> FinalQty;
		-- the FactorToBase slot -> ReceiveQty (see the @INV insert below + header note).
		-- Prior base-qty block:
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
			UpdatedAt = GETUTCDATE()
		WHERE PurchaseId = @PurchaseId;

	------------------- END OF SOURCE TABLE ------------------------------
	
		-- Section 9: stage journal rows in a temp table so the final insert can
		-- stay ordered while the build itself remains set-based.
	CREATE TABLE #PurTxDetail
	(
		TxDetailId int IDENTITY(1,1),
		SortLine INT,
		RowSort INT,
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
		SrcDetailId INT
	)

		-- Section 10: create the TransactionJournal header and seed the @AP row.
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

		IF @TxId IS NULL
		BEGIN
			RAISERROR('TransactionJournal not created for Purchase %d.', 16, 1, @PurchaseNumber);
			RETURN;
		END

		SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@AP'
		EXEC Fn_Adjust_CrDeAmount @AccountId,@FinalTotal,@CrDeAmount OUTPUT

		INSERT INTO #PurTxDetail
			([SortLine]
			,[RowSort]
			,[TxId]
			,[AccountId]
			,[PayeeId]	
			,[Amount]
			,[CrDeAmount])
		VALUES
			(0
			,1
			,@TxId
			,@AccountId
			,@PayeeId
			,@FinalTotal
			,@CrDeAmount)

		-- Section 11: build line-level journal rows set-based.
		-- Preserve the original journal row shape, but generate it set-based.
		-- One PurchaseDetail line can map to multiple TxDetail rows, and those
		-- rows must stay together in baseline order:
		-- A line        -> account row
		-- NonInventory  -> @COGS row
		-- Inventory     -> @COGS row, then @INV row
		-- The staged row order is:
		--   SortLine = PurchaseDetailId
		--   RowSort  = 1 for account/non-inventory/@COGS, 2 for @INV
		-- Final insert then preserves:
		--   @AP first, then one contiguous group per PurchaseDetail line.
		-- Account-line sign handling matches baseline by using IsAccountDebit to
		-- derive Amount and CrDeAmount the same way Fn_Adjust_CrDeAmount does.
		INSERT INTO #PurTxDetail
				([SortLine]
				,[RowSort]
				,[TxId]
				,[AccountId]
				,[PayeeId]
				,[Qty]
				,[Price]
				,[BillQty]
				,[Amount]
				,[CrDeAmount]
				,[SrcDetailId])
		SELECT
				pd.PurchaseDetailId,
				1,
				@TxId,
				pd.AccountId,
				@PayeeId,
				pd.FinalQty,
				-- 4dp Slice-2: entered goods Price -> 4dp. was ROUND(pd.FinalPrice,2)
				ROUND(pd.FinalPrice,4),
				ABS(ROUND(pd.FinalQty * pd.FinalPrice,2)),
				ROUND(pd.FinalQty * pd.FinalPrice,2),
				crde.CrDeAmount,
				pd.PurchaseDetailId
		FROM PurchaseDetail pd
		CROSS APPLY dbo.Fn_CrDeAmount
		(
			pd.AccountId,
			ROUND(pd.FinalQty * pd.FinalPrice,2)
		) crde
		WHERE pd.PurchaseId = @PurchaseId
		  AND pd.LineType = 'A';

		INSERT INTO #PurTxDetail
				([SortLine]
				,[RowSort]
				,[TxId]
				,[AccountId]
				,[PayeeId]
				,[ItemId]
				,[Amount]
				,[CrDeAmount]
				,[SrcDetailId])
		SELECT
			pd.PurchaseDetailId,
			1,
			@TxId,
			cogs.AccountId,
			@PayeeId,
			pd.ItemId,
			ROUND(pd.FinalQty * pd.FinalPrice,2),
			crde.CrDeAmount,
			pd.PurchaseDetailId
		FROM PurchaseDetail pd
		INNER JOIN Item i ON i.ItemId = pd.ItemId
		CROSS JOIN (SELECT AccountId FROM @AcctTable WHERE AccountCode='@COGS') cogs
		CROSS APPLY dbo.Fn_CrDeAmount
		(
			CONVERT(NVARCHAR(20), cogs.AccountId),
			ABS(ROUND(pd.FinalQty * pd.FinalPrice,2))
		) crde
		WHERE pd.PurchaseId = @PurchaseId
		  AND pd.LineType <> 'A'
		  AND i.ItemType = 'NonInventory';

		INSERT INTO #PurTxDetail
				([SortLine]
				,[RowSort]
				,[TxId]
				,[AccountId]
				,[PayeeId]
				,[ItemId]
				,[Amount]
				,[CrDeAmount]
				,[SrcDetailId]
				,[FactorToBase])
		SELECT
			pd.PurchaseDetailId,
			1,
			@TxId,
			cogs.AccountId,
			@PayeeId,
			pd.ItemId,
			0,
			0,
			pd.PurchaseDetailId,
			pd.FactorToBase
		FROM PurchaseDetail pd
		INNER JOIN Item i ON i.ItemId = pd.ItemId
		CROSS JOIN (SELECT AccountId FROM @AcctTable WHERE AccountCode='@COGS') cogs
		WHERE pd.PurchaseId = @PurchaseId
		  AND pd.LineType <> 'A'
		  AND i.ItemType <> 'NonInventory';

		INSERT INTO #PurTxDetail
				([SortLine]
				,[RowSort]
				,[TxId]
				,[AccountId]
				,[PayeeId]
				,[ItemId]
				,[Qty]
				,[Price]
				,[BillQty]
				,[SrcDetailId]
				,[FactorToBase])
		SELECT
			pd.PurchaseDetailId,
			2,
			@TxId,
			inv.AccountId,
			@PayeeId,
			pd.ItemId,
			pd.BaseReceiveQty,                                  -- Qty: base physical (unchanged)
			-- 2026-07-07 Effort-B: @INV entered basis (see header). Price drops x pd.FactorToBase ->
			-- entered FinalPrice (goods; landed added at billing by Shipment_AllocationInventoryClear).
			-- OLD: ROUND(ROUND(pd.FinalPrice,2) * pd.FactorToBase,2),
			-- 4dp Slice-2: entered goods Price -> 4dp. was ROUND(pd.FinalPrice,2)
			ROUND(pd.FinalPrice,4),                            -- Price: entered goods (no landed at insert)
			-- OLD: pd.BaseFinalQty,
			pd.FinalQty,                                       -- BillQty: entered value
			pd.PurchaseDetailId,
			-- OLD: pd.FactorToBase
			pd.ReceiveQty                                      -- FactorToBase slot: entered physical qty (audit)
		FROM PurchaseDetail pd
		INNER JOIN Item i ON i.ItemId = pd.ItemId
		CROSS JOIN (SELECT AccountId FROM @AcctTable WHERE AccountCode='@INV') inv
		WHERE pd.PurchaseId = @PurchaseId
		  AND pd.LineType <> 'A'
		  AND i.ItemType <> 'NonInventory';

		-- Section 12: write staged journal rows to TransactionJournalDetail in
		-- preserved baseline order.
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
			,[FactorToBase])
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
		FROM #PurTxDetail AS p
		ORDER BY SortLine, RowSort, TxDetailId

		-- Section 13: clear temp-cart rows only after durable Purchase,
		-- PurchaseDetail, and journal rows have been written successfully.
		--====================================================================
		DELETE FROM TempPurchase WHERE PayeeId=@PayeeId AND EmpId=@EmpId

		SET @NewPurchaseId = @PurchaseId

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
		THROW;
	END CATCH

	-- Section 14: run post-commit follow-up in the final intended order.
	-- Reordered from the original flow:
	-- Recalc enqueue now happens immediately after commit, before the broader
	-- post-commit helper work. Reason:
	-- 1. queue reliability should not depend on later helper success
	-- 2. this avoids losing inventory recalculation when non-core follow-up fails
	-- 3. queue timing should not depend on later stage/helper recalculation
	EXEC Recalc_AfterInsert @TxId,@ArrivalDate

	-- Non-core purchase recalculation stays after commit.
	EXEC [Purchase_CalcTotalAndPercent] @PurchaseId,@FinalTotal OUTPUT

	-- End Summary:
	--   1. TempPurchase.LineId is the canonical cart order and is persisted directly.
	--   2. Core totals and base quantities stay inline before journal build.
	--   3. TransactionJournalDetail rows are built set-based, but emitted in
	--      preserved baseline per-line order.
	--   4. Purchase_CalcTotalAndPercent remains post-commit follow-up for non-core work.

END
GO
