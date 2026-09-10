-- KLS-4DP-B-Phase2-Slice4b-InventoryAdj_Insert: Class-C variable split (inert-first, Decision 2).
--   Split the overloaded @NewPrice into @NewPrice DECIMAL(18,4) [ENTERED price -> V/B branches] and
--   @JrnCost DECIMAL(18,2) [COMPUTED cost -> Q + C source/dest branches]. Inert: @JrnCost preserves the
--   current 2dp cost truncation (incl. ROUND(transfer,6)->2dp on assignment); @NewPrice holds <=2dp entered
--   today so @Amount is unchanged. NOT setting-gated. 18,6 running-cost accuracy DEFERRED (separate pass).
--   Also widen the entered staging so 4dp entered prices aren't truncated pre-journal: @MyTable.NewPrice -> (18,4)
--   and #InvTxDetail.Price -> (18,6) (match TJD.Price tier). Inert: cost path feeds @JrnCost(18,2).
ALTER PROCEDURE [dbo].[InventoryAdj_Insert]
	@AdjId INT,
	@AdjDate DATE,
	@AdjType NVARCHAR(50),
	@OpenClose NVARCHAR(50),
	@Notes NVARCHAR(255),
	@EmpId INT,
	@NewAdjId INT OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	-- This procedure creates one inventory adjustment and immediately writes its
	-- matching TransactionJournal header and detail rows.
	--
	-- Timing rule:
	-- - Before Receiving  -> Inventory Adj         -> SourceDocOrder 600
	-- - After Receiving   -> Inventory Adj Closing -> SourceDocOrder 695
	--
	-- RecalcQAV is not changed here. It already respects SourceDocOrder.
	--
	-- Active-type guard:
	-- Only Q, V, B, and C remain supported in the live application flow.
	-- Retired types must fail early here so manual calls cannot create a posting
	-- shape that the current recalculation path no longer supports.
	IF @AdjType NOT IN ('Q','V','B','C')
		RAISERROR('Unsupported inventory adjustment type. Only Q, V, B, and C are allowed.', 16, 1);

	IF @AdjType <> 'C'
	BEGIN
		IF NOT EXISTS (
			SELECT 1
			FROM TempInventoryAdj
			WHERE EmpId = @EmpId
			  AND AdjId = 0
			  AND ISNULL(ChangeStatus, '') <> 'D'
		)
			RAISERROR('Add at least one product.', 16, 1);

		IF @AdjType = 'Q' AND EXISTS (
			SELECT 1
			FROM TempInventoryAdj
			WHERE EmpId = @EmpId
			  AND AdjId = 0
			  AND ISNULL(ChangeStatus, '') <> 'D'
			  AND NewQty IS NULL
		)
			RAISERROR('Qty Only adjustment requires quantity.', 16, 1);

		IF @AdjType = 'V' AND EXISTS (
			SELECT 1
			FROM TempInventoryAdj
			WHERE EmpId = @EmpId
			  AND AdjId = 0
			  AND ISNULL(ChangeStatus, '') <> 'D'
			  AND NewPrice IS NULL
		)
			RAISERROR('Value Only adjustment requires price.', 16, 1);

		IF @AdjType = 'B' AND EXISTS (
			SELECT 1
			FROM TempInventoryAdj
			WHERE EmpId = @EmpId
			  AND AdjId = 0
			  AND ISNULL(ChangeStatus, '') <> 'D'
			  AND (NewQty IS NULL OR NewPrice IS NULL)
		)
			RAISERROR('Qty And Value adjustment requires quantity and price. Use Qty Only if this is count correction.', 16, 1);
	END

	-- Section 1. Set up header variables, journal timing, and account lookups.
	DECLARE @IsEdit BIT=0
	DECLARE @OldAdjId INT
	DECLARE @AdjNumber INT
	DECLARE @CreatedAt DATETIME = GETUTCDATE()
	DECLARE @UpdatedAt DATETIME
	DECLARE @TxId BIGINT
	DECLARE @AccountId INT;
	DECLARE @InvAccountId INT;
	DECLARE @SourceDocOrder INT;
	DECLARE @SourceDocType NVARCHAR(50)='Inventory Adj';
	DECLARE @AdjAcctCode NVARCHAR(50);
	DECLARE @Amount DECIMAL(18,2);
	DECLARE @CrDeAmount DECIMAL(18,2)= 0;

	-- Closing adjustments must post after purchase receiving rows on the same day.
	IF @OpenClose = 'After Receiving'
		SET @SourceDocType = 'Inventory Adj Closing';

	EXEC [Get_SourceDocOrder] @SourceDocType, @SourceDocOrder OUTPUT;

	DECLARE @AcctTable AS Table(
		Id INT IDENTITY(1,1),
		AccountCode NVARCHAR(50),
		AccountId INT
	)
	INSERT INTO @AcctTable(AccountCode) VALUES('@INV')
	INSERT INTO @AcctTable(AccountCode) VALUES('@IINVG')
	INSERT INTO @AcctTable(AccountCode) VALUES('@EINVL')
	INSERT INTO @AcctTable(AccountCode) VALUES('@COGS')
	UPDATE t SET t.AccountId=a.AccountId
	FROM @AcctTable AS t INNER JOIN Account AS a ON t.AccountCode=a.AccountCode
	SELECT @InvAccountId=AccountId FROM @AcctTable WHERE AccountCode='@INV'

	-- Section 2. Create the InventoryAdj header row.
    /*
    Legacy edit-via-insert branch retained for reference only.
    Current callers use InventoryAdj_PartialUpdate for edits and call
    InventoryAdj_Insert only for new adjustments with @AdjId = 0.

    IF @AdjId > 0
    BEGIN
        SET @IsEdit = 1;
		SET @UpdatedAt = GETUTCDATE();
        SELECT @AdjNumber = AdjNumber, @CreatedAt = CreatedAt FROM InventoryAdj
        WHERE AdjId = @AdjId;
        DELETE FROM InventoryAdj WHERE AdjId = @AdjId;
    END
    ELSE
        SET @AdjNumber = NEXT VALUE FOR dbo.Seq_AdjNumber;
    */

    SET @AdjNumber = NEXT VALUE FOR dbo.Seq_AdjNumber;
	INSERT INTO [dbo].[InventoryAdj]
			([AdjNumber]
			,[AdjDate]
			,[AdjType]
			,[OpenClose]
			,[Notes]
			,[CreatedAt]
			,[UpdatedAt])
		VALUES
			(@AdjNumber
			,@AdjDate
			,@Adjtype
			,@OpenClose
			,@Notes
			,@CreatedAt
			,@UpdatedAt)
	SELECT @AdjId = SCOPE_IDENTITY();
	SET @NewAdjId = @AdjId

	-- Section 3. Copy staged temp-cart rows into InventoryAdjDetail.
	INSERT INTO [dbo].[InventoryAdjDetail]
			([AdjId]
			,[ItemId]
			,[NewQty]
			,[QtyDiffer]
			,[NewPrice]
			,[Notes]
			,[Direction])
	SELECT
			@AdjId,
			ItemId,
			CASE
				WHEN @AdjType='V' THEN NULL
				WHEN @AdjType='C' AND Direction='S' THEN -ABS(NewQty)
				WHEN @AdjType='C' AND Direction='D' THEN ABS(NewQty)
				ELSE NewQty
			END,
			QtyDiffer,
			CASE WHEN @AdjType='Q' THEN NULL ELSE NewPrice END,
			Notes,
			Direction
	FROM TempInventoryAdj WHERE EmpId=@EmpId AND AdjId=(CASE WHEN @IsEdit=0 THEN 0 ELSE @OldAdjId END)

	INSERT INTO [dbo].[TransactionJournal]
			([TxDate]
			,[TxTime]
			,[SourceDocOrder]
			,[SourceDocType]
			,[SourceDocNumber]
			,[Notes])
     VALUES
			(@AdjDate
			,GETUTCDATE()
			,@SourceDocOrder
			,@SourceDocType
			,@AdjNumber
			,@Notes)
	SELECT @TxId = SCOPE_IDENTITY();

	DECLARE @ItemId INT
	DECLARE @NewQty DECIMAL(18,2)
	-- 4dp Slice-4b: entered adjustment price -> (18,4) [V/B branches]; split from computed cost
	DECLARE @NewPrice DECIMAL(18,4)
	-- 4dp Slice-4b: computed running/transfer cost stays 2dp (Q + C source/dest) -- current behavior preserved;
	-- 18,6 costing accuracy is DEFERRED to a separate controlled costing pass (Decision 2).
	DECLARE @JrnCost DECIMAL(18,2)
	DECLARE @QtyDiff DECIMAL(18,2)
	DECLARE @SrcDetailId INT
	DECLARE @Direction VARCHAR(1)

	DECLARE @MyTable TABLE (
		AutoId INT IDENTITY(1,1) PRIMARY KEY,
		ItemId INT,
		NewQty DECIMAL(18,2),
			QtyDiffer DECIMAL(18,2),
			-- 4dp Slice-4b: entered staging price -> (18,4) so V/B entered price isn't truncated before @NewPrice
			NewPrice DECIMAL(18,4),
			SrcDetailId INT,
			Direction VARCHAR(1)
	)

	-- Journal detail rows are staged first, then inserted in one ordered batch.
	CREATE TABLE #InvTxDetail
	(
		AutoId int IDENTITY(1,1),
		TxId INT,
		AccountId INT,
		ItemId INT,
		Qty DECIMAL(18,2),
		-- 4dp Slice-4b: journal staging Price -> (18,6) to match TransactionJournalDetail.Price tier, so an
		-- entered 4dp price isn't truncated before the journal insert. Inert: cost path feeds @JrnCost(18,2).
		Price DECIMAL(18,6),
		BillQty DECIMAL(18,2),
		Amount DECIMAL(18,2),
		CrDeAmount DECIMAL(18,2),
		SrcDetailId INT
	)

	-- Section 4. Load adjustment detail rows in the order they must post.
	-- Convert/Repack must process source rows before destination rows.
	INSERT INTO	@MyTable(
		ItemId,
		NewQty,
		QtyDiffer,
		NewPrice,
		SrcDetailId,
		Direction)
	SELECT
		ItemId,
		NewQty,
		QtyDiffer,
		NewPrice,
		AdjDetailId,
		Direction
	FROM InventoryAdjDetail WHERE AdjId=@AdjId
	ORDER BY CASE WHEN @AdjType='C' THEN CASE WHEN Direction='S' THEN 0 ELSE 1 END ELSE 0 END, AdjDetailId

	-- Section 5. Pre-calculate convert/repack costs before writing any journal rows.
	DECLARE @TotalSourceCost DECIMAL(18,6) = 0;
	DECLARE @TotalDestQty DECIMAL(18,6) = 0;
	DECLARE @DestUnitCost DECIMAL(18,6) = 0;
	DECLARE @AllocatedSoFar DECIMAL(18,6) = 0;
	DECLARE @DestCount INT = 0;
	DECLARE @DestProcessed INT = 0;

	IF @AdjType = 'C'
	BEGIN
		-- Validation: at least 1 source and 1 destination
		IF NOT EXISTS (SELECT 1 FROM @MyTable WHERE Direction='S' AND NewQty != 0)
			RAISERROR('Convert adjustment requires at least one source item', 16, 1);
		IF NOT EXISTS (SELECT 1 FROM @MyTable WHERE Direction='D' AND NewQty != 0)
			RAISERROR('Convert adjustment requires at least one destination item', 16, 1);

		-- Get total destination qty (must be > 0)
		SELECT @TotalDestQty = SUM(ABS(NewQty)) FROM @MyTable WHERE Direction='D';
		IF @TotalDestQty <= 0
			RAISERROR('Convert adjustment destination total qty must be greater than zero', 16, 1);

		-- Count destination lines for last-line remainder
		SELECT @DestCount = COUNT(*) FROM @MyTable WHERE Direction='D';
	END

	-- Section 6. Load the latest known inventory state for every affected item.
	DECLARE @MaxRow INT
	DECLARE @RowNum INT=1
	SELECT @MaxRow = COUNT(AutoId) FROM @MyTable

	DECLARE @LCloQty DECIMAL(18,6);
	DECLARE @LAvgCost DECIMAL(18,2);
	DECLARE @LInventoryValue  DECIMAL(18,2);
	DECLARE @LastInvTable Table(
		ItemId INT,
		LCloQty DECIMAL(18,6),
		LAvgCost DECIMAL(18,2),
		LInventoryValue DECIMAL(18,2)
	)

	/*
	Legacy Section 6 baseline for quick rollback/reference:

	;WITH cteclo AS
	(
		SELECT tjd.ItemId,ClosingQty,AverageCost,InventoryValue,
		ROW_NUMBER() OVER(PARTITION BY tjd.ItemId ORDER BY tj.TxDate DESC,tj.SourceDocOrder DESC,tjd.TxDetailId DESC) As RN
		FROM TransactionJournal AS tj
		INNER JOIN TransactionJournalDetail AS tjd ON tj.TxId=tjd.TxId
		INNER JOIN @MyTable As m ON m.ItemId=tjd.ItemId
		WHERE TxDate<=@AdjDate AND tjd.AccountId=@InvAccountId
	)
	INSERT INTO @LastInvTable
	SELECT ItemId,ClosingQty,AverageCost,InventoryValue FROM cteclo WHERE RN=1
	*/

	-- Temp table gives SQL Server real rowcount stats for the affected-item set,
	-- which tends to plan better than joining the large ledger directly to @MyTable.
	CREATE TABLE #AdjItems (
		ItemId INT NOT NULL PRIMARY KEY
	);

	INSERT INTO #AdjItems (ItemId)
	SELECT DISTINCT ItemId
	FROM @MyTable;

	;WITH LatestInv AS
	(
		SELECT
			td.ItemId,
			td.ClosingQty,
			td.AverageCost,
			td.InventoryValue,
			ROW_NUMBER() OVER (
				PARTITION BY td.ItemId
				ORDER BY t.TxDate DESC, t.SourceDocOrder DESC, td.TxDetailId DESC
			) AS RN
		FROM #AdjItems AS ai
		INNER JOIN dbo.TransactionJournalDetail AS td
			ON td.ItemId = ai.ItemId
		   AND td.AccountId = @InvAccountId
		INNER JOIN dbo.TransactionJournal AS t
			ON t.TxId = td.TxId
		WHERE t.TxDate <= @AdjDate
	)
	INSERT INTO @LastInvTable (ItemId, LCloQty, LAvgCost, LInventoryValue)
	SELECT ItemId, ClosingQty, AverageCost, InventoryValue
	FROM LatestInv
	WHERE RN = 1;

	DROP TABLE #AdjItems;

	-- For Convert/Repack, source rows must use the authoritative average cost.
	IF @AdjType = 'C'
	BEGIN
		SELECT @TotalSourceCost = SUM(ROUND(ABS(m.NewQty) * ISNULL(li.LAvgCost, 0), 6))
		FROM @MyTable m
		LEFT JOIN @LastInvTable li ON li.ItemId = m.ItemId
		WHERE m.Direction = 'S';

		-- Validate: block if any source has NULL cost history
		IF EXISTS (SELECT 1 FROM @MyTable m LEFT JOIN @LastInvTable li ON li.ItemId = m.ItemId WHERE m.Direction = 'S' AND li.LAvgCost IS NULL)
			RAISERROR('Convert adjustment source item has no cost history. Cannot determine authoritative avg cost.', 16, 1);

		IF @TotalSourceCost <= 0
			RAISERROR('Convert adjustment total source cost must be greater than zero', 16, 1);

		SET @DestUnitCost = ROUND(@TotalSourceCost / @TotalDestQty, 6);
	END

	-- Section 7. Build the TransactionJournalDetail rows one adjustment line at a time.
	-- Each branch below explains how that adjustment type affects inventory value.
	WHILE @RowNum <= @MaxRow
	BEGIN

		SELECT
			@ItemId=ItemId,
			@NewQty=NewQty,
			@NewPrice=NewPrice,
			@QtyDiff=QtyDiffer,
			@SrcDetailId=SrcDetailId,
			@Direction=Direction
		FROM @MyTable WHERE AutoId = @RowNum

		SET @CrDeAmount=0

		SELECT @LCloQty=LCloQty,@LAvgCost=LAvgCost,@LInventoryValue=LInventoryValue
		FROM @LastInvTable WHERE ItemId=@ItemId

		If @AdjType='Q'
		BEGIN
			-- Quantity Only:
			-- keep the current average cost and adjust inventory value only for the quantity delta.
			SET @JrnCost = @LAvgCost
			SET @Amount = ROUND(((@NewQty-@LCloQty) * @JrnCost),2)

			If @Amount>=0
				SET @AdjAcctCode = '@IINVG'
			ELSE IF @Amount<0
				SET @AdjAcctCode = '@EINVL'
			SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode=@AdjAcctCode
			INSERT INTO #InvTxDetail
					([TxId]
					,[AccountId]
					,[ItemId]
					,[Qty]
					,[Price]
					,[BillQty]
					,[Amount]
					,[SrcDetailId])
				VALUES
				   (@TxId
				   ,@AccountId
				   ,@ItemId
				   ,@NewQty
				   ,@JrnCost
				   ,NULL
				   ,ABS(@Amount)
				   ,@SrcDetailId)
			EXEC Fn_Adjust_CrDeAmount @InvAccountId,@Amount,@CrDeAmount OUTPUT
			INSERT INTO #InvTxDetail
			   ([TxId]
			   ,[AccountId]
			   ,[ItemId]
			   ,[Qty]
			   ,[Price]
			   ,[BillQty]
			   ,[Amount]
			   ,[CrDeAmount]
			   ,[SrcDetailId])
			VALUES
			   (@TxId
			   ,@InvAccountId
			   ,@ItemId
			   ,@NewQty
			   ,@JrnCost
			   ,NULL
			   ,@Amount
			   ,@CrDeAmount
			   ,@SrcDetailId)
		END

		IF @AdjType='V'
		BEGIN
			-- Value Only:
			-- keep the current quantity and change value by the difference in average cost.
			SET @NewQty=@LCloQty
			SET @Amount = ROUND((@NewQty * (@NewPrice-@LAvgCost)),2)
			If @Amount>=0
				SET @AdjAcctCode = '@IINVG'
			ELSE IF @Amount<0
				SET @AdjAcctCode = '@EINVL'
			SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode=@AdjAcctCode
			INSERT INTO #InvTxDetail
					([TxId]
					,[AccountId]
					,[ItemId]
					,[Qty]
					,[Price]
					,[BillQty]
					,[Amount]
					,[SrcDetailId])
				VALUES
				   (@TxId
				   ,@AccountId
				   ,@ItemId
				   ,@NewQty
				   ,@NewPrice
				   ,NULL
				   ,ABS(@Amount)
				   ,@SrcDetailId)
			EXEC Fn_Adjust_CrDeAmount @InvAccountId,@Amount,@CrDeAmount OUTPUT
			INSERT INTO #InvTxDetail
			   ([TxId]
			   ,[AccountId]
			   ,[ItemId]
			   ,[Qty]
			   ,[Price]
			   ,[BillQty]
			   ,[Amount]
			   ,[CrDeAmount]
			   ,[SrcDetailId])
			VALUES
			   (@TxId
			   ,@InvAccountId
			   ,@ItemId
			   ,@NewQty
			   ,@NewPrice
			   ,NULL
			   ,@Amount
			   ,@CrDeAmount
			   ,@SrcDetailId)
		END

		IF @AdjType='B'
		BEGIN
			-- Qty And Value:
			-- replace the full closing quantity and value with the new stated amount.
			SET @Amount = ROUND((@NewQty * @NewPrice),2) - @LInventoryValue

			If @Amount>=0
				SET @AdjAcctCode = '@IINVG'
			ELSE IF @Amount<0
				SET @AdjAcctCode = '@EINVL'
			SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode=@AdjAcctCode
			INSERT INTO #InvTxDetail
					([TxId]
					,[AccountId]
					,[ItemId]
					,[Qty]
					,[Price]
					,[BillQty]
					,[Amount]
					,[SrcDetailId])
				VALUES
				   (@TxId
				   ,@AccountId
				   ,@ItemId
				   ,@NewQty
				   ,@NewPrice
				   ,NULL
				   ,ABS(@Amount)
				   ,@SrcDetailId)
			EXEC Fn_Adjust_CrDeAmount @InvAccountId,@Amount,@CrDeAmount OUTPUT
			INSERT INTO #InvTxDetail
			   ([TxId]
			   ,[AccountId]
			   ,[ItemId]
			   ,[Qty]
			   ,[Price]
			   ,[BillQty]
			   ,[Amount]
			   ,[CrDeAmount]
			   ,[SrcDetailId])
			VALUES
			   (@TxId
			   ,@InvAccountId
			   ,@ItemId
			   ,@NewQty
			   ,@NewPrice
			   ,NULL
			   ,@Amount
			   ,@CrDeAmount
			   ,@SrcDetailId)
		END

		/*
		Retired adjustment types kept only as commented reference:
		- A  = Direct Amount
		- N  = Normalization
		- QR = Quantity Reset
		These types no longer exist in live data and are not supported by the
		current active posting/recalculation path. Do not restore them casually
		without also restoring end-to-end RecalcQAV coverage.

		IF @AdjType='A'
		BEGIN
			SET @Amount = ROUND((@NewQty * @NewPrice),2)
			EXEC Fn_Adjust_CrDeAmount @InvAccountId,@Amount,@CrDeAmount OUTPUT
			INSERT INTO #InvTxDetail
			   ([TxId],[AccountId],[ItemId],[Qty],[Price],[BillQty],[Amount],[CrDeAmount],[SrcDetailId])
			VALUES
			   (@TxId,@InvAccountId,@ItemId,@NewQty,@NewPrice,NULL,@Amount,@CrDeAmount,@SrcDetailId)
		END

		IF @AdjType='N'
		BEGIN
			SET @NewPrice = @LAvgCost
			SET @Amount = ROUND((@NewQty * @NewPrice),2)
			SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'
			INSERT INTO #InvTxDetail
			   ([TxId],[AccountId],[ItemId],[Qty],[Price],[SrcDetailId])
			VALUES
			   (@TxId,@AccountId,@ItemId,@NewQty,@NewPrice,@SrcDetailId)
			INSERT INTO #InvTxDetail
			   ([TxId],[AccountId],[ItemId],[Qty],[Price],[SrcDetailId])
			VALUES
			   (@TxId,@InvAccountId,@ItemId,@NewQty,@NewPrice,@SrcDetailId)
		END

		If @AdjType='QR'
		BEGIN
			SET @NewPrice = @LAvgCost
			SET @Amount = ROUND((@NewQty * @NewPrice),2)

			If @Amount>=0
				SET @AdjAcctCode = '@IINVG'
			ELSE IF @Amount<0
				SET @AdjAcctCode = '@EINVL'

			SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode=@AdjAcctCode
			INSERT INTO #InvTxDetail
					([TxId],[AccountId],[ItemId],[Qty],[Price],[BillQty],[Amount],[CrDeAmount],[SrcDetailId])
				VALUES
				   (@TxId,@AccountId,@ItemId,@NewQty,@NewPrice,NULL,ABS(@Amount),@CrDeAmount,@SrcDetailId)
			EXEC Fn_Adjust_CrDeAmount @InvAccountId,@Amount,@CrDeAmount OUTPUT
			INSERT INTO #InvTxDetail
			   ([TxId],[AccountId],[ItemId],[Qty],[Price],[BillQty],[Amount],[CrDeAmount],[SrcDetailId])
			VALUES
			   (@TxId,@InvAccountId,@ItemId,@NewQty,@NewPrice,NULL,@Amount,@CrDeAmount,@SrcDetailId)
		END
		*/

		IF @AdjType='C'
		BEGIN
			-- Convert/Repack:
			-- source rows reduce inventory at authoritative average cost,
			-- destination rows increase inventory at the allocated destination cost.
			IF @Direction = 'S'
			BEGIN
				SET @JrnCost = @LAvgCost
				SET @Amount = ROUND(@NewQty * @JrnCost, 2)

				If @Amount >= 0
					SET @AdjAcctCode = '@IINVG'
				ELSE
					SET @AdjAcctCode = '@EINVL'

				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode=@AdjAcctCode
				INSERT INTO #InvTxDetail
						([TxId],[AccountId],[ItemId],[Qty],[Price],[BillQty],[Amount],[SrcDetailId])
					VALUES
					   (@TxId,@AccountId,@ItemId,@NewQty,@JrnCost,NULL,ABS(@Amount),@SrcDetailId)

				EXEC Fn_Adjust_CrDeAmount @InvAccountId,@Amount,@CrDeAmount OUTPUT
				INSERT INTO #InvTxDetail
				   ([TxId],[AccountId],[ItemId],[Qty],[Price],[BillQty],[Amount],[CrDeAmount],[SrcDetailId])
				VALUES
				   (@TxId,@InvAccountId,@ItemId,@NewQty,@JrnCost,NULL,@Amount,@CrDeAmount,@SrcDetailId)
			END
			ELSE IF @Direction = 'D'  -- Destination: increase inventory with allocated cost
			BEGIN
				SET @DestProcessed = @DestProcessed + 1

				-- Last-line remainder: last dest gets remaining to ensure exact balance
				IF @DestProcessed = @DestCount
					SET @JrnCost = ROUND((@TotalSourceCost - @AllocatedSoFar) / @NewQty, 6)
				ELSE
					SET @JrnCost = @DestUnitCost

				SET @Amount = ROUND(@NewQty * @JrnCost, 2)

				-- Track allocated value for last-line remainder
				IF @DestProcessed < @DestCount
					SET @AllocatedSoFar = @AllocatedSoFar + @Amount

				If @Amount >= 0
					SET @AdjAcctCode = '@IINVG'
				ELSE
					SET @AdjAcctCode = '@EINVL'

				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode=@AdjAcctCode
				INSERT INTO #InvTxDetail
						([TxId],[AccountId],[ItemId],[Qty],[Price],[BillQty],[Amount],[SrcDetailId])
					VALUES
					   (@TxId,@AccountId,@ItemId,@NewQty,@JrnCost,NULL,ABS(@Amount),@SrcDetailId)

				EXEC Fn_Adjust_CrDeAmount @InvAccountId,@Amount,@CrDeAmount OUTPUT
				INSERT INTO #InvTxDetail
				   ([TxId],[AccountId],[ItemId],[Qty],[Price],[BillQty],[Amount],[CrDeAmount],[SrcDetailId])
				VALUES
				   (@TxId,@InvAccountId,@ItemId,@NewQty,@JrnCost,NULL,@Amount,@CrDeAmount,@SrcDetailId)
			END
		END

	NEXT_ITEM:
		SET @RowNum += 1
	END

	-- Section 8. Write the staged journal rows in a stable order.
	INSERT INTO TransactionJournalDetail
			([TxId]
			,[AccountId]
			,[ItemId]
			,[Qty]
			,[Price]
			,[BillQty]
			,[Amount]
			,[CrDeAmount]
			,[SourceDetailId])
	SELECT [TxId]
			,[AccountId]
			,[ItemId]
			,[Qty]
			,[Price]
			,[BillQty]
			,[Amount]
			,[CrDeAmount]
			,[SrcDetailId]
	FROM #InvTxDetail ORDER BY AutoId
	DELETE TempInventoryAdj WHERE EmpId=@EmpId

	-- Section 9. Trigger recalculation from this adjustment date forward.
	EXEC Recalc_AfterInsert @TxId,@AdjDate
END
GO
-- KLS-4DP-InvAdjPU-ConvertNewPrice-widen (2026-07-09): @ConvertTable.NewPrice widened (18,2)->(18,4).
--   The Slice-4b note below deferred this (kept inert while no >2dp NewPrice existed). 4dp NewPrice ENTRY is now
--   live (inventory-adj input on kls-price-input), so the convert-flow staging column would truncate 35.999->36.
--   #ConvertTxDetail.Price stays (18,2): it carries @JrnCost (cost), not the entered price -- costing carve-out holds.
-- KLS-4DP-B-Phase2-Slice4b-InventoryAdj_PartialUpdate: Class-C variable split (inert-first, Decision 2).
--   Split @NewPrice: @NewPrice DECIMAL(18,4) [ENTERED, main Q/V/B section] + @JrnCost DECIMAL(18,2) [COMPUTED
--   convert cost, C section]. @TempInvTable.NewPrice -> (18,4) [entered]. Left @ConvertTable.NewPrice +
--   #ConvertTxDetail.Price at (18,2). Inert: @JrnCost preserves current 2dp cost truncation (incl.
--   ROUND(transfer,6)->2dp); @NewPrice <=2dp entered today. NOT setting-gated. 18,6 costing DEFERRED.
ALTER PROCEDURE [dbo].[InventoryAdj_PartialUpdate]
	@AdjId INT,
	@AdjDate DATE,
	@AdjType NVARCHAR(50),
	@OpenClose NVARCHAR(50),
	@Notes NVARCHAR(255),
	@EmpId INT
AS
BEGIN
	SET NOCOUNT ON;

	-- This procedure updates an existing inventory adjustment and keeps its
	-- TransactionJournal header aligned with the selected timing.
	--
	-- Timing rule:
	-- - Before Receiving  -> Inventory Adj         -> SourceDocOrder 600
	-- - After Receiving   -> Inventory Adj Closing -> SourceDocOrder 695
	--
	-- RecalcQAV is not changed here. It already respects SourceDocOrder.
	--
	-- Active-type guard:
	-- Only Q, V, B, and C remain supported in the live application flow.
	-- Retired types must fail early here so manual calls cannot update an
	-- adjustment into a posting shape that the current recalculation path no
	-- longer supports.
	IF @AdjType NOT IN ('Q','V','B','C')
		RAISERROR('Unsupported inventory adjustment type. Only Q, V, B, and C are allowed.', 16, 1);

	IF @AdjType <> 'C'
	BEGIN
		IF NOT EXISTS (
			SELECT 1
			FROM TempInventoryAdj
			WHERE EmpId = @EmpId
			  AND AdjId = @AdjId
			  AND ISNULL(ChangeStatus, '') <> 'D'
		)
			RAISERROR('Add at least one product.', 16, 1);

		IF @AdjType = 'Q' AND EXISTS (
			SELECT 1
			FROM TempInventoryAdj
			WHERE EmpId = @EmpId
			  AND AdjId = @AdjId
			  AND ISNULL(ChangeStatus, '') <> 'D'
			  AND NewQty IS NULL
		)
			RAISERROR('Qty Only adjustment requires quantity.', 16, 1);

		IF @AdjType = 'V' AND EXISTS (
			SELECT 1
			FROM TempInventoryAdj
			WHERE EmpId = @EmpId
			  AND AdjId = @AdjId
			  AND ISNULL(ChangeStatus, '') <> 'D'
			  AND NewPrice IS NULL
		)
			RAISERROR('Value Only adjustment requires price.', 16, 1);

		IF @AdjType = 'B' AND EXISTS (
			SELECT 1
			FROM TempInventoryAdj
			WHERE EmpId = @EmpId
			  AND AdjId = @AdjId
			  AND ISNULL(ChangeStatus, '') <> 'D'
			  AND (NewQty IS NULL OR NewPrice IS NULL)
		)
			RAISERROR('Qty And Value adjustment requires quantity and price. Use Qty Only if this is count correction.', 16, 1);
	END

	-- Section 1. Load the target adjustment header and resolve journal timing.
	DECLARE @TxId BIGINT
	DECLARE @TxDate DATE
	DECLARE @RowNum INT=1
	DECLARE @MaxRow INT
	DECLARE @AdjNumber INT
	DECLARE @ItemId INT
	DECLARE @NewQty DECIMAL(18,2)
	-- 4dp Slice-4b: entered adjustment price -> (18,4) [main Q/V/B section]; split from computed cost
	DECLARE @NewPrice DECIMAL(18,4)
	-- 4dp Slice-4b: computed convert cost stays 2dp (convert section) -- current behavior preserved; 18,6 deferred
	DECLARE @JrnCost DECIMAL(18,2)
	DECLARE @QtyDiff DECIMAL(18,2)
	DECLARE @NoteDetail NVARCHAR(255)
	DECLARE @ChangeStatus VARCHAR(1)
	DECLARE @SrcDetailId INT
	DECLARE @Direction VARCHAR(1)
	DECLARE @InvAccountId INT
	DECLARE @AccountId INT
	DECLARE @SourceDocOrder INT
	DECLARE @SourceDocType NVARCHAR(50) = 'Inventory Adj'
	SELECT @AdjNumber=AdjNumber FROM InventoryAdj WHERE AdjId=@AdjId

	IF @OpenClose = 'After Receiving'
		SET @SourceDocType = 'Inventory Adj Closing'

	EXEC [Get_SourceDocOrder] @SourceDocType, @SourceDocOrder OUTPUT

	-- Existing rows may already be stored under either inventory-adjustment doc type.
	SELECT @TxId=TxId,@TxDate=TxDate
	FROM TransactionJournal
	WHERE SourceDocNumber=@AdjNumber
	  AND SourceDocType IN ('Inventory Adj', 'Inventory Adj Closing')

	DECLARE @AcctTable AS Table(
		Id INT IDENTITY(1,1),
		AccountCode NVARCHAR(50),
		AccountId INT
	)
	INSERT INTO @AcctTable(AccountCode) VALUES('@INV')
	INSERT INTO @AcctTable(AccountCode) VALUES('@IINVG')
	INSERT INTO @AcctTable(AccountCode) VALUES('@EINVL')
	INSERT INTO @AcctTable(AccountCode) VALUES('@COGS')
	UPDATE t SET t.AccountId=a.AccountId
	FROM @AcctTable AS t INNER JOIN Account AS a ON t.AccountCode=a.AccountCode
	SELECT @InvAccountId=AccountId FROM @AcctTable WHERE AccountCode='@INV'

	-- Section 2. Convert/Repack uses a full rebuild because source and destination
	-- cost allocation must be recalculated from scratch.
	--
	-- Plain-language summary:
	-- When an edit changes a convert/repack adjustment, we do not try to patch the
	-- old journal rows in place. Instead, we:
	-- 1. read the staged convert rows from TempInventoryAdj,
	-- 2. find the latest pre-adjustment inventory cost for the affected items,
	-- 3. delete the old detail/journal rows for this adjustment,
	-- 4. rebuild the detail rows,
	-- 5. rebuild the journal rows in the correct source-then-destination order,
	-- 6. update the header and queue recalculation.
	--
	-- The cost lookup below now follows the same "known item set first" idea used
	-- in InventoryAdj_Insert Section 6. SQL Server plans better when we materialize
	-- the small affected item set into a temp table before joining the large ledger.
	IF @AdjType = 'C'
	BEGIN
		-- Step 2.1. Build the staged convert list before deleting existing rows.
		DECLARE @ConvertTable TABLE (
			AutoId INT IDENTITY(1,1) PRIMARY KEY,
			ItemId INT,
			NewQty DECIMAL(18,2),
			NewPrice DECIMAL(18,4),   -- 4dp: was (18,2) -- convert-flow staging truncated entered 4dp NewPrice
			Direction VARCHAR(1),
			SrcDetailId INT
		)

		INSERT INTO @ConvertTable (ItemId, NewQty, NewPrice, Direction)
		SELECT
			ItemId,
			CASE
				WHEN Direction='S' THEN -ABS(NewQty)
				WHEN Direction='D' THEN ABS(NewQty)
				ELSE NewQty
			END,
			NewPrice,
			Direction
		FROM TempInventoryAdj
		WHERE EmpId=@EmpId AND AdjId=@AdjId
		ORDER BY CASE WHEN Direction='S' THEN 0 ELSE 1 END, TempAdjId

		-- Step 2.2. Read authoritative average costs before deleting current detail rows.
		-- We need the last known pre-adjustment cost for each source item so the
		-- rebuilt convert posting uses the same authoritative baseline as insert.
		DECLARE @LastInvTable Table(ItemId INT, LAvgCost DECIMAL(18,6))

		/*
		Legacy Step 2.2 baseline for quick rollback/reference:

		;WITH cteclo AS (
			SELECT tjd.ItemId, tjd.AverageCost,
			ROW_NUMBER() OVER(PARTITION BY tjd.ItemId ORDER BY tj.TxDate DESC, tj.SourceDocOrder DESC, tjd.TxDetailId DESC) As RN
			FROM TransactionJournal AS tj
			INNER JOIN TransactionJournalDetail AS tjd ON tj.TxId=tjd.TxId
			INNER JOIN @ConvertTable AS m ON m.ItemId=tjd.ItemId
			WHERE tj.TxDate<=@AdjDate AND tjd.AccountId=@InvAccountId
			  AND tj.TxId != @TxId  -- exclude current adjustment
		)
		INSERT INTO @LastInvTable SELECT ItemId, AverageCost FROM cteclo WHERE RN=1
		*/

		CREATE TABLE #ConvertItems (
			ItemId INT NOT NULL PRIMARY KEY
		);

		INSERT INTO #ConvertItems (ItemId)
		SELECT DISTINCT ItemId
		FROM @ConvertTable;

		;WITH LatestCost AS (
			SELECT
				tjd.ItemId,
				tjd.AverageCost,
				ROW_NUMBER() OVER (
					PARTITION BY tjd.ItemId
					ORDER BY tj.TxDate DESC, tj.SourceDocOrder DESC, tjd.TxDetailId DESC
				) AS RN
			FROM #ConvertItems AS ci
			INNER JOIN dbo.TransactionJournalDetail AS tjd
				ON tjd.ItemId = ci.ItemId
			   AND tjd.AccountId = @InvAccountId
			INNER JOIN dbo.TransactionJournal AS tj
				ON tj.TxId = tjd.TxId
			WHERE tj.TxDate <= @AdjDate
			  AND tj.TxId != @TxId  -- exclude current adjustment
		)
		INSERT INTO @LastInvTable (ItemId, LAvgCost)
		SELECT ItemId, AverageCost
		FROM LatestCost
		WHERE RN = 1;

		DROP TABLE #ConvertItems;

		-- Step 2.3. Clear the old adjustment detail and journal detail rows.
		DELETE FROM TransactionJournalDetail WHERE TxId=@TxId
		DELETE FROM InventoryAdjDetail WHERE AdjId=@AdjId

		-- Step 2.4. Copy all staged rows into InventoryAdjDetail.
		INSERT INTO [dbo].[InventoryAdjDetail]
				([AdjId],[ItemId],[NewQty],[QtyDiffer],[NewPrice],[Notes],[Direction])
		SELECT
			@AdjId,
			ItemId,
			CASE
				WHEN Direction='S' THEN -ABS(NewQty)
				WHEN Direction='D' THEN ABS(NewQty)
				ELSE NewQty
			END,
			QtyDiffer,
			NewPrice,
			Notes,
			Direction
		FROM TempInventoryAdj
		WHERE EmpId=@EmpId AND AdjId=@AdjId

		-- Step 2.5. Reconnect staged rows to their new AdjDetailId values.
		;WITH NewDetails AS (
			SELECT AdjDetailId, ItemId, Direction,
			ROW_NUMBER() OVER(ORDER BY CASE WHEN Direction='S' THEN 0 ELSE 1 END, AdjDetailId) AS RN
			FROM InventoryAdjDetail WHERE AdjId=@AdjId
		)
		UPDATE c SET c.SrcDetailId = nd.AdjDetailId
		FROM @ConvertTable c
		INNER JOIN NewDetails nd ON nd.RN = c.AutoId

		-- Step 2.6. Calculate source cost totals and destination allocation.
		DECLARE @TotalSourceCost DECIMAL(18,6)
		DECLARE @TotalDestQty DECIMAL(18,6)
		DECLARE @DestUnitCost DECIMAL(18,6)
		DECLARE @AllocatedSoFar DECIMAL(18,6) = 0
		DECLARE @DestCount INT
		DECLARE @DestProcessed INT = 0

		SELECT @TotalSourceCost = SUM(ROUND(ABS(c.NewQty) * ISNULL(li.LAvgCost, 0), 6))
		FROM @ConvertTable c
		LEFT JOIN @LastInvTable li ON li.ItemId = c.ItemId
		WHERE c.Direction = 'S'

		SELECT @TotalDestQty = SUM(ABS(NewQty)) FROM @ConvertTable WHERE Direction='D'
		SELECT @DestCount = COUNT(*) FROM @ConvertTable WHERE Direction='D'

		IF @TotalDestQty > 0
			SET @DestUnitCost = ROUND(@TotalSourceCost / @TotalDestQty, 6)
		ELSE
			SET @DestUnitCost = 0

		-- Step 2.7. Stage the new journal detail rows.
		CREATE TABLE #ConvertTxDetail (
			AutoId INT IDENTITY(1,1),
			TxId BIGINT, AccountId INT, ItemId INT,
			Qty DECIMAL(18,2), Price DECIMAL(18,2),
			Amount DECIMAL(18,2), CrDeAmount DECIMAL(18,2),
			SrcDetailId INT
		)

		DECLARE @Amount DECIMAL(18,2)
		DECLARE @CrDeAmount DECIMAL(18,2)
		DECLARE @AdjAcctCode NVARCHAR(50)
		DECLARE @CMaxRow INT, @CRowNum INT = 1
		SELECT @CMaxRow = COUNT(*) FROM @ConvertTable

		WHILE @CRowNum <= @CMaxRow
		BEGIN
			SELECT @ItemId=ItemId, @NewQty=NewQty, @Direction=Direction, @SrcDetailId=SrcDetailId
			FROM @ConvertTable WHERE AutoId=@CRowNum

			IF @Direction = 'S'
			BEGIN
				-- Source rows always leave inventory at authoritative average cost.
				SELECT @JrnCost = ISNULL(LAvgCost, 0) FROM @LastInvTable WHERE ItemId=@ItemId
				SET @Amount = ROUND(@NewQty * @JrnCost, 2)
			END
			ELSE
			BEGIN
				-- Destination rows receive the allocated convert cost.
				SET @DestProcessed = @DestProcessed + 1
				IF @DestProcessed = @DestCount
					SET @JrnCost = ROUND((@TotalSourceCost - @AllocatedSoFar) / @NewQty, 6)
				ELSE
					SET @JrnCost = @DestUnitCost

				SET @Amount = ROUND(@NewQty * @JrnCost, 2)
				IF @DestProcessed < @DestCount
					SET @AllocatedSoFar = @AllocatedSoFar + @Amount
			END

			IF @Amount >= 0
				SET @AdjAcctCode = '@IINVG'
			ELSE
				SET @AdjAcctCode = '@EINVL'

			SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode=@AdjAcctCode

			-- Offset row
			INSERT INTO #ConvertTxDetail (TxId, AccountId, ItemId, Qty, Price, Amount, SrcDetailId)
			VALUES (@TxId, @AccountId, @ItemId, @NewQty, @JrnCost, ABS(@Amount), @SrcDetailId)

			-- Inventory row
			EXEC Fn_Adjust_CrDeAmount @InvAccountId, @Amount, @CrDeAmount OUTPUT
			INSERT INTO #ConvertTxDetail (TxId, AccountId, ItemId, Qty, Price, Amount, CrDeAmount, SrcDetailId)
			VALUES (@TxId, @InvAccountId, @ItemId, @NewQty, @JrnCost, @Amount, @CrDeAmount, @SrcDetailId)

			SET @CRowNum += 1
		END

		-- Step 2.8. Insert staged journal detail rows in a stable order.
		INSERT INTO TransactionJournalDetail
			([TxId],[AccountId],[ItemId],[Qty],[Price],[Amount],[CrDeAmount],[SourceDetailId])
		SELECT TxId, AccountId, ItemId, Qty, Price, Amount, CrDeAmount, SrcDetailId
		FROM #ConvertTxDetail ORDER BY AutoId

		DROP TABLE #ConvertTxDetail

		-- Step 2.9. Save the header, switch journal timing if needed, clear temp rows,
		-- and recalculate from the correct date.
		UPDATE InventoryAdj SET AdjType=@AdjType, AdjDate=@AdjDate, OpenClose=@OpenClose, Notes=@Notes, UpdatedAt=GETUTCDATE()
		WHERE AdjId=@AdjId
		UPDATE TransactionJournal
		SET TxDate=@AdjDate,
			TxTime=GETUTCDATE(),
			SourceDocType=@SourceDocType,
			SourceDocOrder=@SourceDocOrder
		WHERE TxId=@TxId
		DELETE TempInventoryAdj WHERE EmpId=@EmpId

		IF @AdjDate!=@TxDate
		BEGIN
			IF @TxDate<@AdjDate
				EXEC [Recalc_AfterInsert] @TxId,@TxDate
			ELSE
				EXEC [Recalc_AfterInsert] @TxId,@AdjDate
		END
		ELSE
			EXEC [Recalc_AfterInsert] @TxId,@AdjDate

		RETURN
	END

	-- Section 3. Non-convert adjustments apply staged insert, update, and delete
	-- changes directly to detail rows and matching journal rows.
	--
	-- Plain-language summary:
	-- For non-convert edits, TempInventoryAdj tells us which lines were inserted,
	-- updated, or deleted. We replay those staged actions one row at a time.
	-- This keeps the edit logic narrow and avoids rebuilding the whole adjustment
	-- when the change is just a normal qty/value edit.
	DECLARE @TempInvTable TABLE (
		[AutoId] INT IDENTITY(1,1) NOT NULL,
		[ItemId] INT NULL,
		[NewQty] DECIMAL(18,2) NULL,
		[QtyDiffer] DECIMAL(18,2) NULL,
		-- 4dp Slice-4b: entered temp price -> (18,4) so a 4dp entered adjustment price flows in the main section
		[NewPrice] DECIMAL(18,4) NULL,
		[Notes] NVARCHAR(255) NULL,
		[ChangeStatus] varchar(1) NULL,
		[SrcDetailId] int NULL,
		[Direction] varchar(1) NULL
	)
	INSERT INTO @TempInvTable
	SELECT
      ItemId, NewQty, QtyDiffer, NewPrice, Notes, ChangeStatus, AdjDetailId, Direction
	FROM TempInventoryAdj AS t
	WHERE EmpId=@EmpId AND AdjId=@AdjId AND ChangeStatus IS NOT NULL

	-- Each staged row tells this procedure whether to insert, update, or delete
	-- one adjustment line and its matching journal rows.
	SELECT @MaxRow=COUNT(AutoId) FROM @TempInvTable

	WHILE @RowNum <= @MaxRow
	BEGIN
		SELECT @ChangeStatus=ChangeStatus,
		@SrcDetailId=SrcDetailId,
		@ItemId=ItemId,
		@NewQty=NewQty,
		@QtyDiff=QtyDiffer,
		@NewPrice=NewPrice,
		@NoteDetail=Notes,
		@Direction=Direction
		FROM @TempInvTable
		WHERE AutoId=@RowNum

		IF @ChangeStatus='I'
		BEGIN
			-- New detail rows must keep their own staged line note. The header note
			-- is saved later on InventoryAdj itself and should not overwrite the line.
			--
			-- Retired-type note:
			-- Only Q, V, and B remain active in this non-convert insert path.
			-- A, N, and QR are retired in live usage and do not have full active
			-- recalculation support. Their old posting logic is kept below as a
			-- commented reference only for rollback/history review.
			--
			-- Semantic storage note:
			-- For Q adjustments, the saved adjustment row should keep Adj Price as
			-- NULL because price is derived from inventory history, not entered here.
			-- For V adjustments, the saved adjustment row should keep Adj Qty as
			-- NULL because quantity is not an entered value for value-only changes.
			INSERT INTO [dbo].[InventoryAdjDetail]
				([AdjId],[ItemId],[NewQty],[QtyDiffer],[NewPrice],[Notes],[Direction])
			VALUES(@AdjId, @ItemId, CASE WHEN @AdjType='V' THEN NULL ELSE @NewQty END, @QtyDiff, CASE WHEN @AdjType='Q' THEN NULL ELSE @NewPrice END, @NoteDetail, @Direction)
			SET @SrcDetailId=SCOPE_IDENTITY();

			IF @AdjType IN ('Q','V','B')
			BEGIN
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@IINVG'
				INSERT INTO TransactionJournalDetail ([TxId],[AccountId],[ItemId],[SourceDetailId])
				VALUES (@TxId, @AccountId, @ItemId, @SrcDetailId)
				INSERT INTO TransactionJournalDetail ([TxId],[AccountId],[ItemId],[Qty],[Price],[SourceDetailId])
				VALUES (@TxId, @InvAccountId, @ItemId, @NewQty, @NewPrice, @SrcDetailId)
			END
			/*
			Retired non-convert insert branches kept only as commented reference:

			ELSE IF @AdjType IN ('N')
			BEGIN
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'
				INSERT INTO TransactionJournalDetail ([TxId],[AccountId],[ItemId],[SourceDetailId])
				VALUES (@TxId, @AccountId, @ItemId, @SrcDetailId)
				INSERT INTO TransactionJournalDetail ([TxId],[AccountId],[ItemId],[Qty],[Price],[SourceDetailId])
				VALUES (@TxId, @InvAccountId, @ItemId, @NewQty, @NewPrice, @SrcDetailId)
			END
			ELSE IF @AdjType IN ('A')
			BEGIN
				INSERT INTO TransactionJournalDetail ([TxId],[AccountId],[ItemId],[Qty],[Price],[SourceDetailId])
				VALUES (@TxId, @InvAccountId, @ItemId, @NewQty, @NewPrice, @SrcDetailId)
			END
			*/
		END
		ELSE IF @ChangeStatus='U'
		BEGIN
			-- Plain-language summary:
			-- For normal line edits, InventoryAdjDetail keeps the staged row values,
			-- but the @INV journal row should only copy price from the temp row when
			-- that adjustment type truly uses an entered price. Qty-only style edits
			-- (Q / QR / N) often keep NewPrice at 0 in temp/detail rows because the UI
			-- disables price input. In those cases, overwriting the journal price with
			-- 0 is wrong; RecalcQAV later recalculates amount/qty state but does not
			-- restore the journal Price column. Value-only edits should likewise keep
			-- the saved Adj Qty as NULL because quantity is not entered on that path.
			UPDATE InventoryAdjDetail
			SET NewQty=CASE WHEN @AdjType='V' THEN NULL ELSE @NewQty END, QtyDiffer=@QtyDiff, NewPrice=CASE WHEN @AdjType='Q' THEN NULL ELSE @NewPrice END, Notes=@NoteDetail, Direction=@Direction
			WHERE AdjDetailId=@SrcDetailId

			/*
			Legacy update baseline for quick rollback/reference:

			UPDATE TransactionJournalDetail SET Qty=@NewQty, Price=@NewPrice
			WHERE TxId=@TxId AND SourceDetailId=@SrcDetailId AND AccountId=@InvAccountId
			*/

			-- Only Q remains in the qty-only update path. QR and N are retired and
			-- their former behavior is kept below as a commented reference.
			IF @AdjType IN ('Q')
			BEGIN
				UPDATE TransactionJournalDetail
				SET Qty=@NewQty
				WHERE TxId=@TxId AND SourceDetailId=@SrcDetailId AND AccountId=@InvAccountId
			END
			ELSE
			BEGIN
				UPDATE TransactionJournalDetail
				SET Qty=@NewQty, Price=@NewPrice
				WHERE TxId=@TxId AND SourceDetailId=@SrcDetailId AND AccountId=@InvAccountId
			END

			/*
			Retired qty-only update condition kept only as commented reference:

			IF @AdjType IN ('Q','QR','N')
			BEGIN
				UPDATE TransactionJournalDetail
				SET Qty=@NewQty
				WHERE TxId=@TxId AND SourceDetailId=@SrcDetailId AND AccountId=@InvAccountId
			END
			*/
		END
		ELSE IF @ChangeStatus='D'
		BEGIN
			DELETE FROM InventoryAdjDetail WHERE AdjDetailId=@SrcDetailId
			DELETE FROM TransactionJournalDetail WHERE SourceDetailId=@SrcDetailId AND TxId=@TxId
		END
		SET @RowNum+=1
	END

	-- Section 4. Save header changes, switch journal timing if needed, and trigger
	-- recalculation only for the affected rows.
	UPDATE InventoryAdj SET AdjType=@AdjType, AdjDate=@AdjDate, OpenClose=@OpenClose, Notes=@Notes, UpdatedAt=GETUTCDATE()
	WHERE AdjId=@AdjId
	UPDATE TransactionJournal
	SET TxDate=@AdjDate,
		TxTime=GETUTCDATE(),
		SourceDocType=@SourceDocType,
		SourceDocOrder=@SourceDocOrder
	WHERE TxId=@TxId
	DELETE TempInventoryAdj WHERE EmpId=@EmpId

	IF @AdjDate!=@TxDate
	BEGIN
		IF @TxDate<@AdjDate
			EXEC [Recalc_AfterInsert] @TxId,@TxDate
		ELSE
			EXEC [Recalc_AfterInsert] @TxId,@AdjDate
	END
	ELSE
	BEGIN
		INSERT INTO RecalculationLog(ItemId,TxId,TxDate)
		SELECT ItemId,@TxId,@AdjDate FROM @TempInvTable WHERE ChangeStatus IS NOT NULL;
	END
END
GO
