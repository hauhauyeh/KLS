CREATE OR ALTER PROCEDURE [dbo].[InventoryAdj_PartialUpdate]
	@AdjId INT,
	@AdjDate DATE,
	@AdjType NVARCHAR(50),
	@Notes NVARCHAR(255),
	@EmpId INT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @TxId BIGINT
	DECLARE @TxDate DATE
	DECLARE @RowNum INT=1
	DECLARE @MaxRow INT
	DECLARE @AdjNumber INT
	DECLARE @ItemId INT
	DECLARE @NewQty DECIMAL(18,2)
	DECLARE @NewPrice DECIMAL(18,2)
	DECLARE @QtyDiff DECIMAL(18,2)
	DECLARE @NoteDetail NVARCHAR(255)
	DECLARE @ChangeStatus VARCHAR(1)
	DECLARE @SrcDetailId INT
	DECLARE @Direction VARCHAR(1)
	DECLARE @InvAccountId INT
	DECLARE @AccountId INT
	SELECT @AdjNumber=AdjNumber FROM InventoryAdj WHERE AdjId=@AdjId
	SELECT @TxId=TxId,@TxDate=TxDate FROM TransactionJournal WHERE SourceDocNumber=@AdjNumber AND SourceDocType='Inventory Adj'
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

	-- ========================================================
	-- Convert type: delete + recreate (full rebuild)
	-- ========================================================
	IF @AdjType = 'C'
	BEGIN
		-- 1. Build item list from temp table BEFORE deleting anything
		DECLARE @ConvertTable TABLE (
			AutoId INT IDENTITY(1,1) PRIMARY KEY,
			ItemId INT,
			NewQty DECIMAL(18,2),
			NewPrice DECIMAL(18,2),
			Direction VARCHAR(1),
			SrcDetailId INT
		)
		-- Temp table has all items (changed + unchanged)
		INSERT INTO @ConvertTable (ItemId, NewQty, NewPrice, Direction)
		SELECT ItemId, NewQty, NewPrice, Direction
		FROM TempInventoryAdj
		WHERE EmpId=@EmpId AND AdjId=@AdjId
		ORDER BY CASE WHEN Direction='S' THEN 0 ELSE 1 END, TempAdjId

		-- 2. Get authoritative avg costs BEFORE deleting TxDetail
		--    Exclude current adjustment's own TxId to avoid reading zeroed-out values
		DECLARE @LastInvTable Table(ItemId INT, LAvgCost DECIMAL(18,6))
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

		-- 3. Delete existing detail + journal entries
		DELETE FROM TransactionJournalDetail WHERE TxId=@TxId
		DELETE FROM InventoryAdjDetail WHERE AdjId=@AdjId

		-- 4. Copy ALL temp items to InventoryAdjDetail
		INSERT INTO [dbo].[InventoryAdjDetail]
				([AdjId],[ItemId],[NewQty],[QtyDiffer],[NewPrice],[Notes],[Direction])
		SELECT @AdjId, ItemId, NewQty, QtyDiffer, NewPrice, Notes, Direction
		FROM TempInventoryAdj
		WHERE EmpId=@EmpId AND AdjId=@AdjId

		-- 5. Update SrcDetailId in @ConvertTable from newly inserted AdjDetailIds
		;WITH NewDetails AS (
			SELECT AdjDetailId, ItemId, Direction,
			ROW_NUMBER() OVER(ORDER BY CASE WHEN Direction='S' THEN 0 ELSE 1 END, AdjDetailId) AS RN
			FROM InventoryAdjDetail WHERE AdjId=@AdjId
		)
		UPDATE c SET c.SrcDetailId = nd.AdjDetailId
		FROM @ConvertTable c
		INNER JOIN NewDetails nd ON nd.RN = c.AutoId

		-- 5. Calculate source costs + dest allocation
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

		-- 6. Create journal entries for each item
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
				-- Source: use authoritative avg cost
				SELECT @NewPrice = ISNULL(LAvgCost, 0) FROM @LastInvTable WHERE ItemId=@ItemId
				SET @Amount = ROUND(@NewQty * @NewPrice, 2)
			END
			ELSE
			BEGIN
				-- Destination: use allocated cost with last-line remainder
				SET @DestProcessed = @DestProcessed + 1
				IF @DestProcessed = @DestCount
					SET @NewPrice = ROUND((@TotalSourceCost - @AllocatedSoFar) / @NewQty, 6)
				ELSE
					SET @NewPrice = @DestUnitCost

				SET @Amount = ROUND(@NewQty * @NewPrice, 2)
				IF @DestProcessed < @DestCount
					SET @AllocatedSoFar = @AllocatedSoFar + @Amount
			END

			IF @Amount >= 0
				SET @AdjAcctCode = '@IINVG'
			ELSE
				SET @AdjAcctCode = '@EINVL'

			SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode=@AdjAcctCode

			-- Offset line
			INSERT INTO #ConvertTxDetail (TxId, AccountId, ItemId, Qty, Price, Amount, SrcDetailId)
			VALUES (@TxId, @AccountId, @ItemId, @NewQty, @NewPrice, ABS(@Amount), @SrcDetailId)

			-- INV line
			EXEC Fn_Adjust_CrDeAmount @InvAccountId, @Amount, @CrDeAmount OUTPUT
			INSERT INTO #ConvertTxDetail (TxId, AccountId, ItemId, Qty, Price, Amount, CrDeAmount, SrcDetailId)
			VALUES (@TxId, @InvAccountId, @ItemId, @NewQty, @NewPrice, @Amount, @CrDeAmount, @SrcDetailId)

			SET @CRowNum += 1
		END

		-- 7. Bulk insert journal entries
		INSERT INTO TransactionJournalDetail
			([TxId],[AccountId],[ItemId],[Qty],[Price],[Amount],[CrDeAmount],[SourceDetailId])
		SELECT TxId, AccountId, ItemId, Qty, Price, Amount, CrDeAmount, SrcDetailId
		FROM #ConvertTxDetail ORDER BY AutoId

		DROP TABLE #ConvertTxDetail

		-- 8. Update header + cleanup + recalc
		UPDATE InventoryAdj SET AdjType=@AdjType, AdjDate=@AdjDate, Notes=@Notes, UpdatedAt=GETUTCDATE()
		WHERE AdjId=@AdjId
		UPDATE TransactionJournal SET TxDate=@AdjDate, TxTime=GETUTCDATE() WHERE TxId=@TxId
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

	-- ========================================================
	-- Non-Convert types: incremental update (existing logic)
	-- ========================================================
	DECLARE @TempInvTable TABLE (
		[AutoId] INT IDENTITY(1,1) NOT NULL,
		[ItemId] INT NULL,
		[NewQty] DECIMAL(18,2) NULL,
		[QtyDiffer] DECIMAL(18,2) NULL,
		[NewPrice] DECIMAL(18,2) NULL,
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
			INSERT INTO [dbo].[InventoryAdjDetail]
				([AdjId],[ItemId],[NewQty],[QtyDiffer],[NewPrice],[Notes],[Direction])
			VALUES(@AdjId, @ItemId, @NewQty, @QtyDiff, @NewPrice, @Notes, @Direction)
			SET @SrcDetailId=SCOPE_IDENTITY();

			IF @AdjType IN ('Q','V','B','QR')
			BEGIN
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@IINVG'
				INSERT INTO TransactionJournalDetail ([TxId],[AccountId],[ItemId],[SourceDetailId])
				VALUES (@TxId, @AccountId, @ItemId, @SrcDetailId)
				INSERT INTO TransactionJournalDetail ([TxId],[AccountId],[ItemId],[Qty],[Price],[SourceDetailId])
				VALUES (@TxId, @InvAccountId, @ItemId, @NewQty, @NewPrice, @SrcDetailId)
			END
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
		END
		ELSE IF @ChangeStatus='U'
		BEGIN
			UPDATE InventoryAdjDetail
			SET NewQty=@NewQty, QtyDiffer=@QtyDiff, NewPrice=@NewPrice, Notes=@NoteDetail, Direction=@Direction
			WHERE AdjDetailId=@SrcDetailId
			UPDATE TransactionJournalDetail SET Qty=@NewQty, Price=@NewPrice
			WHERE TxId=@TxId AND SourceDetailId=@SrcDetailId AND AccountId=@InvAccountId
		END
		ELSE IF @ChangeStatus='D'
		BEGIN
			DELETE FROM InventoryAdjDetail WHERE AdjDetailId=@SrcDetailId
			DELETE FROM TransactionJournalDetail WHERE SourceDetailId=@SrcDetailId AND TxId=@TxId
		END
		SET @RowNum+=1
	END

	UPDATE InventoryAdj SET AdjType=@AdjType, AdjDate=@AdjDate, Notes=@Notes, UpdatedAt=GETUTCDATE()
	WHERE AdjId=@AdjId
	UPDATE TransactionJournal SET TxDate=@AdjDate, TxTime=GETUTCDATE() WHERE TxId=@TxId
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
