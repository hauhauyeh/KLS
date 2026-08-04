-- KLS-4DP-InvAdjPU-ConvertNewPrice-widen (2026-07-09): @ConvertTable.NewPrice widened (18,2)->(18,4).
--   The Slice-4b note below deferred this (kept inert while no >2dp NewPrice existed). 4dp NewPrice ENTRY is now
--   live (inventory-adj input on kls-price-input), so the convert-flow staging column would truncate 35.999->36.
--   #ConvertTxDetail.Price stays (18,2): it carries @JrnCost (cost), not the entered price -- costing carve-out holds.
-- KLS-4DP-B-Phase2-Slice4b-InventoryAdj_PartialUpdate: Class-C variable split (inert-first, Decision 2).
--   Split @NewPrice: @NewPrice DECIMAL(18,4) [ENTERED, main Q/V/B section] + @JrnCost DECIMAL(18,2) [COMPUTED
--   convert cost, C section]. @TempInvTable.NewPrice -> (18,4) [entered]. Left @ConvertTable.NewPrice +
--   #ConvertTxDetail.Price at (18,2). Inert: @JrnCost preserves current 2dp cost truncation (incl.
--   ROUND(transfer,6)->2dp); @NewPrice <=2dp entered today. NOT setting-gated. 18,6 costing DEFERRED.
CREATE   PROCEDURE [dbo].[InventoryAdj_PartialUpdate]
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
		SELECT ItemId, NewQty, NewPrice, Direction
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
		SELECT @AdjId, ItemId, NewQty, QtyDiffer, NewPrice, Notes, Direction
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
		SELECT ItemId,@TxId,@AdjDate FROM @TempInvTable WHERE ChangeStatus IS NOT NULL
	END
END


