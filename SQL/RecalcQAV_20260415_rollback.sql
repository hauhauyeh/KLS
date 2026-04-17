IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.TransactionJournalDetail')
      AND name = 'IX_TransactionJournalDetail_AccountId_ItemId_TxId'
)
BEGIN
    DROP INDEX IX_TransactionJournalDetail_AccountId_ItemId_TxId
    ON dbo.TransactionJournalDetail;
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE   PROCEDURE [dbo].[RecalcQAV] --EXEC [RecalcQAV] 419,'02/25/26'
    @ItemId INT,
    @BeginDate DATE,
	@LCloQty DECIMAL(18,6) OUTPUT,
	@LAvgCost DECIMAL(18,6) OUTPUT,
	@LInventoryValue DECIMAL(18,6) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @InvAccountId INT
	DECLARE @COGSAccountId INT
	DECLARE @InvGainAccountId INT
	DECLARE @InvLossAccountId INT
	DECLARE @AREAccountId INT
	SELECT
		@InvAccountId     = MAX(CASE WHEN AccountCode = '@INV'   THEN AccountId END),
		@COGSAccountId    = MAX(CASE WHEN AccountCode = '@COGS'  THEN AccountId END),
		@InvGainAccountId = MAX(CASE WHEN AccountCode = '@IINVG' THEN AccountId END),
		@InvLossAccountId = MAX(CASE WHEN AccountCode = '@EINVL' THEN AccountId END),
		@AREAccountId     = MAX(CASE WHEN AccountCode = '@ARE'   THEN AccountId END)
	FROM dbo.Account
	WHERE AccountCode IN ('@INV', '@COGS', '@IINVG', '@EINVL', '@ARE');
	-- 1. Get Last Date (before BeginDate)
	DECLARE @LastDate DATE;
	SELECT @LastDate = MAX(tj.TxDate)
	FROM dbo.TransactionJournal tj
	INNER JOIN dbo.TransactionJournalDetail tjd ON tj.TxId = tjd.TxId
	WHERE tj.TxDate < @BeginDate
		AND tjd.AccountId = @InvAccountId
		AND tjd.ItemId = @ItemId;
	-- 2. Index/re-sort relevant transactions into a temp table
	CREATE TABLE #QAVTable (
		AutoId INT IDENTITY(1,1) PRIMARY KEY,
		TxDate DATE,
		SourceDocOrder INT,
		TxDetailId BIGINT,
		SourceDocNum INT
	);
	INSERT INTO #QAVTable (TxDate, SourceDocOrder, TxDetailId, SourceDocNum)
	SELECT tj.TxDate, tj.SourceDocOrder, tjd.TxDetailId, tj.SourceDocNumber
	FROM dbo.TransactionJournal AS tj INNER JOIN dbo.TransactionJournalDetail AS tjd ON tj.TxId = tjd.TxId
	WHERE
		(tj.TxDate >= ISNULL(@LastDate,@BeginDate)) and
		--IF @LastDate IS NULL SET @LastDate = @BeginDate
		(tjd.AccountId = @InvAccountId) and 
		(tjd.ItemId = @ItemId)
	ORDER BY tj.TxDate, tj.SourceDocOrder, tjd.TxDetailId
	-- 3. Get Item Retail Factor (set to 1 if not found or zero)
	--DECLARE @RetailFactor MONEY = 1;
	--SELECT @RetailFactor = CASE WHEN RetailFactor = 0 THEN 1 ELSE RetailFactor END
	--FROM Item
	--WHERE ItemCode = @ItemId;
	-- 4. Set initial values
	SET @LCloQty = 0; SET @LAvgCost = 0; SET @LInventoryValue = 0;
	
	DECLARE @LastDateMaxId INT, @TxDetailId INT;
	IF @LastDate IS NOT NULL
	BEGIN
		SELECT @LastDateMaxId = MAX(AutoId) FROM #QAVTable WHERE TxDate = @LastDate;
		SELECT @TxDetailId = TxDetailId FROM #QAVTable WHERE AutoId = @LastDateMaxId;
		SELECT @LCloQty = ISNULL(ClosingQty, 0), 
		@LAvgCost = ISNULL(AverageCost, 0), 
		@LInventoryValue = ISNULL(InventoryValue, 0)
		FROM TransactionJournalDetail
		WHERE TxDetailId = @TxDetailId;
	END
	-- 5. Set up loop variables for row-by-row processing
	DECLARE @RowNum INT = 1, @MaxRow INT, @NextTxDate DATE;
	SELECT @MaxRow = COUNT(*) FROM #QAVTable;
	IF @MaxRow = 0 RETURN;
	-- 6. Find the first transaction to start processing
	-- Find the earliest transaction date on or after @BeginDate in the temp table
	-- Find the AutoId (row number) of the first transaction on that date (this will be the starting point for the loop)
	SELECT @NextTxDate = MIN(TxDate) FROM #QAVTable WHERE TxDate>=@BeginDate
	SELECT @RowNum = MIN(AutoId) FROM #QAVTable WHERE TxDate = @NextTxDate	
	/*
		start to recalclating
	*/
	DECLARE
		@MyId INT,
		@MyTxDate DATE,
		@MySourceDocOrder INT,
		@MyTxDetailId BIGINT,
		@MySourceDocNum INT,
		
		@Qty DECIMAL(18,6),
		@Price DECIMAL(18,6),
		@BillQty DECIMAL(18,6),
		@FactorToBase DECIMAL(18,6),
		@CloQty DECIMAL(18,6),
		@AvgCost DECIMAL(18,6),
		@InventoryValue DECIMAL(18,6),
		@COGSAdjAmount DECIMAL(18,6),
		@RoundingError DECIMAL(18,6),
		@DiffInventoryValue DECIMAL(18,6),
		@Amount DECIMAL(18,6),
		@CrDeAmt DECIMAL(18,6),
		@AdjType NVARCHAR(50),
		@AccountId INT,
		@PayeeId INT,
		@NewAdjAccountCode NVARCHAR(50),
		@IsDebit BIT
	WHILE @RowNum <= @MaxRow
	BEGIN
		
		-- Fetch transaction meta info for the current row from the temp table
		SELECT @MyId = AutoId, @MyTxDate = TxDate, @MySourceDocOrder = SourceDocOrder, @MyTxDetailId = TxDetailId, @MySourceDocNum = SourceDocNum
		FROM #QAVTable WHERE AutoId = @RowNum;
		-- Fetch inventory transaction details for the current transaction detail ID
		SELECT @Qty = Qty, @Price = Price, @BillQty = BillQty, @PayeeId = PayeeId, @FactorToBase = ISNULL(FactorToBase,1)
		FROM TransactionJournalDetail WHERE TxDetailId = @MyTxDetailId;
		--@InventoryValue only for Calculate AvgCost. has no other purpose.
		--When in Sales, AvgCost is not change.
		--@Amount is actual Value changed in 'INV'
		--There is miss leading think @InventoryValue relate to @Amount.
		--Final SUM(CASE WHEN t.SourceDocType='Sales' THEN TD.Qty*-1 ELSE TD.Qty END) AS Qty
		--SourceDocOrder in (300, 305, 680, 685), It is purchase
		--300 Old Purchase
		--305 Old Purchase Debit Memo
		--680 Cur Purchase
		--685 Cur Purchase Debit Memo
		--310 PayNow Check Purchase
		--320 PayNow Credit Card Purchase
		IF @MySourceDocOrder IN (300,305,310,320,680,685) 
		BEGIN
			-- Step 1: Initialize
			SET @COGSAdjAmount = 0
			SET @Price = ABS(@Price)  -- Always positive
			SET @CloQty = @LCloQty + @Qty  -- New inventory quantity
			-- Step 2: Calculate base purchase value
			SET @DiffInventoryValue = ROUND(@BillQty * @Price, 6)
			-- Step 3: Calculate COGS adjustment if needed
			IF @LCloQty < 0
			BEGIN
				IF @CloQty >= 0
				BEGIN
					-- Full recovery from negative inventory
					SET @COGSAdjAmount = ROUND(ABS(@LCloQty) * (@Price - @LAvgCost), 6)
				END
				ELSE
				BEGIN
					-- Still partially negative after transaction
					IF @Qty > 0
					BEGIN
						-- Normal purchase: only the buy-back portion needs adjustment
						SET @COGSAdjAmount = ROUND(ABS(@Qty) * (@Price - @LAvgCost), 6)
					END
					ELSE IF @Qty < 0
					BEGIN
						-- Purchase return: reduce previously assumed inventory value
						SET @COGSAdjAmount = ROUND(ABS(@Qty) * (@Price - @LAvgCost), 6) * -1
					END
					ELSE IF @Qty = 0
					BEGIN
						-- No quantity impact (e.g., value-only adjustment)
						IF @BillQty > 0
						BEGIN
							-- COGS increase
							SET @COGSAdjAmount = ROUND(ABS(@BillQty) * (@Price), 6)
						END
						ELSE IF @BillQty < 0
						BEGIN
							-- COGS Decrease
							SET @COGSAdjAmount = ROUND(ABS(@BillQty) * (@Price), 6) * -1
						END
					END
				END
			END
			
			-- Step 4: Inventory Amount must offset from COGS Adjustment (purchase + COGS correction)
			SET @Amount = @DiffInventoryValue - @COGSAdjAmount
			-- Step 5: Update final inventory value
			SET @InventoryValue = @LInventoryValue + @Amount
			--print @Amount
			-- Step 6: Calculate new average cost (only if meaningful)
			IF @CloQty > 0 AND @InventoryValue > 0
				SET @AvgCost = ROUND(@InventoryValue / @CloQty, 6)
			ELSE
				SET @AvgCost = @LAvgCost
			--@INV RECALC
			SET @Amount = ISNULL(@Amount, 0);
			IF @Amount = 0
				SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
			ELSE --IF @IsDebit = 1 --@INV
				SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
			UPDATE TransactionJournalDetail SET 
				--Price = @Price, -- in case user enter
				ClosingQty = @CloQty,
				AverageCost = @AvgCost,
				InventoryValue = @InventoryValue,
				Amount = @Amount,
				CrDeAmount = @CrDeAmt
			WHERE TxDetailId = @MyTxDetailId
			--PAIRED @COGS RECALC
			SELECT @AccountId=AccountId FROM TransactionJournalDetail WHERE TxDetailId=@MyTxDetailId-1
			--SELECT TOP 1 @MyTxDetailId = TxDetailId, @ChartAcctCode = ChartAcctCode
			--FROM TransactionJournalDetail WHERE TxDetailId < @MyTxDetailId ORDER BY TxDetailId DESC
			IF @AccountId = @COGSAccountId --'@COGS'
			BEGIN
				SET	@Amount=ISNULL(@COGSAdjAmount,0)
				IF @Amount = 0
					SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
				ELSE --IF @IsDebit = 1 --@COGS
					SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
				UPDATE TransactionJournalDetail SET 
					Amount = @Amount,
					CrDeAmount = @CrDeAmt
				WHERE TxDetailId = @MyTxDetailId - 1
			END
			ELSE
				SET @Amount = NULL; SET @CrDeAmt = NULL; --SET @DebitAmt = NULL; SET @CreditAmt = NULL;
		END
		--if SourceDocOrder is 500 then Sales
		ELSE IF @MySourceDocOrder IN (500,505)
		BEGIN
				--SET @CloQty = @LCloQty - @Qty
				--IF (@CloQty>0) AND (@CloQty-FLOOR(@CloQty))<(1/@RetailFactor/2)
				--	SET @CloQty=FLOOR(@CloQty)
				--SET @AvgCost = @LAvgCost
				--SET @DiffInventoryValue = ROUND((@ExtTotal * @LAvgCost),2)*-1  --ExtTotal = BillQty
				--SET @InventoryValue = @LInventoryValue + @DiffInventoryValue
				--SET @Amount = @DiffInventoryValue
				--SET	@Amount=ISNULL(@Amount,0)
		-- Step 0: Fallback for RetailFactor to avoid division by zero
			IF @FactorToBase IS NULL OR @FactorToBase = 0
				SET @FactorToBase = 1  -- Default to 1 if not set
			-- Step 1: Calculate closing quantity
			-- Sales: @Qty > 0  reduces inventory
			-- Return: @Qty < 0  increases inventory
			SET @CloQty = @LCloQty - @Qty  -- Subtracting a negative qty = adding
			-- Step 2: Round down leftover fractional units (e.g., bottle-level sales)
			-- Only applies when inventory is still positive and the leftover is a small fraction
			--IF (@CloQty > 0) AND (@CloQty - FLOOR(@CloQty)) < (1.0 / @RetailFactor / 2)
				--SET @CloQty = FLOOR(@CloQty)
			IF (ABS(@CloQty) > 0) AND (ABS(ABS(@CloQty) - FLOOR(ABS(@CloQty))) < (1.0 / @FactorToBase / 2))
				SET @CloQty = SIGN(@CloQty) * FLOOR(ABS(@CloQty))
			-- Step 3: Keep average cost unchanged (sales/returns do not affect AvgCost)
			SET @AvgCost = @LAvgCost
			-- Step 4: Calculate inventory value change
			-- Sales: @BillQty > 0  inventory value goes down (multiply by -1)
			-- Return: @BillQty < 0  inventory value goes up (multiply by -1 makes it positive)
			SET @DiffInventoryValue = ROUND(@BillQty * @LAvgCost, 6) * -1
			-- Step 5: Update inventory value
			SET @InventoryValue = @LInventoryValue + @DiffInventoryValue
			-- Step 6: Set transaction amount (used in journal entry or tracking)
			SET @Amount = @DiffInventoryValue
			--@INV RECALC
			SET @Amount = ISNULL(@Amount, 0);
			IF @Amount = 0
				SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
			ELSE --IF @IsDebit = 1 --@INV
				SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
				
			UPDATE TransactionJournalDetail SET 
				--Price = @Price,
				ClosingQty = @CloQty,
				AverageCost = @AvgCost,
				InventoryValue = @InventoryValue,
				Amount = @Amount,
				CrDeAmount = @CrDeAmt
			WHERE TxDetailId = @MyTxDetailId
			
			--PAIRED @COGS RECALC
			SELECT @AccountId=AccountId FROM TransactionJournalDetail WHERE TxDetailId=@MyTxDetailId-1
			--SELECT TOP 1 @MyTxDetailId = TxDetailId, @ChartAcctCode = ChartAcctCode
			--FROM TransactionJournalDetail WHERE TxDetailId < @MyTxDetailId ORDER BY TxDetailId DESC
			IF @AccountId = @COGSAccountId--'@COGS'
			BEGIN
				SET	@Amount=ISNULL(-@Amount,0)
				IF @Amount = 0
					SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
				ELSE --IF @IsDebit = 1 --@COGS
					SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
				UPDATE TransactionJournalDetail SET 
					Amount = @Amount,
					CrDeAmount = @CrDeAmt
				WHERE TxDetailId = @MyTxDetailId-1
			END
			ELSE
				SET @Amount = NULL; SET @CrDeAmt = NULL; --SET @DebitAmt = NULL; SET @CreditAmt = NULL;
		END	
		--if SourceDocOrder is 600 then inventory adj.
		ELSE IF @MySourceDocOrder IN (600, 250)
		BEGIN
			SELECT @AdjType = AdjType FROM InventoryAdj WHERE AdjNumber = @MySourceDocNum
			IF @AdjType = 'Q' -- Quantity Adjustment
			BEGIN
				-- Step 1: Update closing quantity based on physical count
				SET @CloQty = @Qty                   -- Final counted quantity
				SET @Qty = @CloQty - @LCloQty        -- Adjustment quantity (difference from last recorded)
				-- Step 2: Calculate the change in inventory value
				SET @DiffInventoryValue = ROUND(@Qty * @LAvgCost, 6)
				-- Step 3: Keep the average cost unchanged during count adjustment
				SET @AvgCost = @LAvgCost
				-- Step 4: Update inventory value and adjustment amount
				SET @InventoryValue = @LInventoryValue + @DiffInventoryValue
				SET @Amount = @DiffInventoryValue
					
				--@INV RECALC
				SET @Amount = ISNULL(@Amount, 0);
				IF @Amount = 0
					SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
				ELSE --IF @IsDebit = 1 --@INV
					SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
				
				UPDATE TransactionJournalDetail SET 
					--Qty = @CloQty, 
					--Price = @LAvgCost,
					--ExtTotal = NULL,
					ClosingQty = @CloQty,
					AverageCost = @AvgCost,
					InventoryValue = @InventoryValue,
					Amount = @Amount,
					CrDeAmount = @CrDeAmt,
					InventoryQty = @CloQty
				WHERE TxDetailId = @MyTxDetailId	
				
				-- PAIRED ACCOUNT (@IINVG, @EINVL, @ARE) RECALC
				--SELECT @ChartAcctCode=ChartAcctCode FROM TransactionJournalDetail WHERE TxDetailId=@MyTxDetailId-1
				--SELECT TOP 1 @MyTxDetailId = TxDetailId, @ChartAcctCode = ChartAcctCode
				--FROM TransactionJournalDetail WHERE TxDetailId < @MyTxDetailId ORDER BY TxDetailId DESC
				IF @Amount >= 0
				BEGIN
					SET @AccountId = @InvGainAccountId --'@IINVG'
					SET @IsDebit=0
				END
				ELSE IF @Amount < 0
				BEGIN
					SET @AccountId = 
					CASE 
						WHEN @PayeeId IS NULL THEN @InvLossAccountId --'@EINVL'
						ELSE @AREAccountId --'@ARE'
					END
					SET @Amount = -(@Amount)
					SET @IsDebit=1
				END
				IF @Amount = 0
					SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
				ELSE IF @IsDebit = 1  -- Debit-normal account (Asset, Expense)
					SET @CrDeAmt = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
				ELSE IF @IsDebit = 0  -- Credit-normal account (Liability, Equity, Revenue)
					SET @CrDeAmt = CASE WHEN @Amount > 0 THEN ABS(@Amount) ELSE -ABS(@Amount) END;
				UPDATE TransactionJournalDetail SET 
					--Price = @LAvgCost,
					AccountId = @AccountId,
					Amount = @Amount,
					CrDeAmount = @CrDeAmt
				WHERE TxDetailId = @MyTxDetailId - 1
			END
			ELSE IF @AdjType = 'V' -- Value Adjustment
			BEGIN
				-- Step 1: Ensure the new unit cost is treated as a positive value
				SET @Price = ABS(@Price)
				-- Step 2: Retain current closing quantity (no change in physical stock)
				SET @CloQty = @LCloQty
				-- Step 3: Calculate the value difference due to cost update
				SET @DiffInventoryValue = ROUND(@LCloQty * (@Price - @LAvgCost), 6)
				-- Step 4: Update the average cost to the new unit cost
				SET @AvgCost = @Price
				-- Step 5: Update inventory value and adjustment amount
				SET @InventoryValue = @LInventoryValue + @DiffInventoryValue
				SET @Amount = @DiffInventoryValue
				--@INV RECALC
				SET @Amount = ISNULL(@Amount, 0);
				IF @Amount = 0
					SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
				ELSE --IF @IsDebit = 1 --@INV
					SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
					
				UPDATE TransactionJournalDetail SET 
					--Qty = @CloQty, 
					--Price = @Price,
					--ExtTotal = NULL,
					ClosingQty = @CloQty,
					AverageCost = @AvgCost,
					InventoryValue = @InventoryValue,
					Amount = @Amount,
					CrDeAmount = @CrDeAmt,
					InventoryQty = @LCloQty
				WHERE TxDetailId = @MyTxDetailId	
				
				-- PAIRED ACCOUNT (@IINVG, @EINVL, @ARE) RECALC
				--SELECT @ChartAcctCode=ChartAcctCode FROM TransactionJournalDetail WHERE TxDetailId=@MyTxDetailId-1
				--SELECT TOP 1 @MyTxDetailId = TxDetailId, @ChartAcctCode = ChartAcctCode
				--FROM TransactionJournalDetail WHERE TxDetailId < @MyTxDetailId ORDER BY TxDetailId DESC
				IF @Amount >= 0
				BEGIN
					SET @AccountId = @InvGainAccountId --'@IINVG'
					SET @IsDebit=0
				END
				ELSE IF @Amount < 0
				BEGIN
					SET @AccountId = 
					CASE 
						WHEN @PayeeId IS NULL THEN @InvLossAccountId --'@EINVL'
						ELSE @AREAccountId --'@ARE'
					END
					SET @Amount = -(@Amount)
					SET @IsDebit=1
				END
				IF @Amount = 0
					SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
				ELSE IF @IsDebit = 1  -- Debit-normal account (Asset, Expense)
					SET @CrDeAmt = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
				ELSE IF @IsDebit = 0  -- Credit-normal account (Liability, Equity, Revenue)
					SET @CrDeAmt = CASE WHEN @Amount > 0 THEN ABS(@Amount) ELSE -ABS(@Amount) END;
				UPDATE TransactionJournalDetail SET 
					--Price = @LAvgCost,
					AccountId = @AccountId,
					Amount = @Amount,
					CrDeAmount = @CrDeAmt
				WHERE TxDetailId = @MyTxDetailId - 1
			END
			ELSE IF @AdjType = 'B' -- Quantity & Value Adjustment
			BEGIN
				-- Step 1: Ensure cost is positive
				SET @Price = ABS(@Price)
				-- Step 2: Set closing quantity to physical count
				SET @CloQty = @Qty
				-- Step 3: Recalculate new inventory value
				SET @InventoryValue = ROUND(@Qty * @Price, 6)
				-- Step 4: Update average cost to new price
				SET @AvgCost = @Price
				-- Step 5: Calculate adjustment amount (for accounting)
				SET @Amount = @InventoryValue - @LInventoryValue
				--@INV RECALC
				SET @Amount = ISNULL(@Amount, 0);
				IF @Amount = 0
					SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
				ELSE --IF @IsDebit = 1 --@INV
					SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
				UPDATE TransactionJournalDetail SET 
					--Qty = @CloQty, 
					--Price = @Price,
					--ExtTotal = NULL,
					ClosingQty = @CloQty,
					AverageCost = @AvgCost,
					InventoryValue = @InventoryValue,
					Amount = @Amount,
					CrDeAmount = @CrDeAmt,
					InventoryQty = @Qty
				WHERE TxDetailId = @MyTxDetailId	
				-- PAIRED ACCOUNT (@IINVG, @EINVL, @ARE) RECALC
				--SELECT @ChartAcctCode=ChartAcctCode FROM TransactionJournalDetail WHERE TxDetailId=@MyTxDetailId-1
				--SELECT TOP 1 @MyTxDetailId = TxDetailId, @ChartAcctCode = ChartAcctCode
				--FROM TransactionJournalDetail WHERE TxDetailId < @MyTxDetailId ORDER BY TxDetailId DESC
				IF @Amount >= 0
				BEGIN
					SET @AccountId = @InvGainAccountId --'@IINVG'
					SET @IsDebit=0
				END
				ELSE IF @Amount < 0
				BEGIN
					SET @AccountId = 
					CASE 
						WHEN @PayeeId IS NULL THEN @InvLossAccountId --'@EINVL'
						ELSE @AREAccountId --'@ARE'
					END
					SET @Amount = -(@Amount)
					SET @IsDebit=1
				END
				IF @Amount = 0
					SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
				ELSE IF @IsDebit = 1  -- Debit-normal account (Asset, Expense)
					SET @CrDeAmt = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
				ELSE IF @IsDebit = 0  -- Credit-normal account (Liability, Equity, Revenue)
					SET @CrDeAmt = CASE WHEN @Amount > 0 THEN ABS(@Amount) ELSE -ABS(@Amount) END;
				UPDATE TransactionJournalDetail SET 
					--Price = @LAvgCost,
					AccountId = @AccountId,
					Amount = @Amount,
					CrDeAmount = @CrDeAmt
				WHERE TxDetailId = @MyTxDetailId - 1
			END	

			ELSE IF @AdjType = 'C' -- Convert/Repack
			BEGIN
				-- Delta-based qty (not absolute like 'Q')
				SET @CloQty = @LCloQty + @Qty

				IF @Qty > 0  -- Destination: recalc avg cost (purchase behavior)
				BEGIN
					SET @Price = ABS(@Price)
					IF @CloQty > 0
						SET @AvgCost = ROUND((@LInventoryValue + (@Qty * @Price)) / @CloQty, 6)
					ELSE
						SET @AvgCost = @Price

					SET @InventoryValue = ROUND(@CloQty * @AvgCost, 6)
					SET @Amount = @InventoryValue - @LInventoryValue
				END
				ELSE  -- Source: keep avg cost (sales behavior)
				BEGIN
					SET @AvgCost = @LAvgCost
					SET @InventoryValue = ROUND(@CloQty * @AvgCost, 6)
					SET @Amount = @InventoryValue - @LInventoryValue
				END

				-- @INV line update
				SET @Amount = ISNULL(@Amount, 0);
				IF @Amount = 0
					SET @CrDeAmt = 0;
				ELSE
					SET @CrDeAmt = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;

				UPDATE TransactionJournalDetail SET
					ClosingQty = @CloQty,
					AverageCost = @AvgCost,
					InventoryValue = @InventoryValue,
					Amount = @Amount,
					CrDeAmount = @CrDeAmt,
					InventoryQty = @CloQty
				WHERE TxDetailId = @MyTxDetailId

				-- Offset line (same gain/loss pattern as other adj types)
				IF @Amount >= 0
				BEGIN
					SET @AccountId = @InvGainAccountId
					SET @IsDebit = 0
				END
				ELSE
				BEGIN
					SET @AccountId = CASE WHEN @PayeeId IS NULL THEN @InvLossAccountId ELSE @AREAccountId END
					SET @Amount = -(@Amount)
					SET @IsDebit = 1
				END

				IF @Amount = 0
					SET @CrDeAmt = 0;
				ELSE IF @IsDebit = 1
					SET @CrDeAmt = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
				ELSE IF @IsDebit = 0
					SET @CrDeAmt = CASE WHEN @Amount > 0 THEN ABS(@Amount) ELSE -ABS(@Amount) END;

				UPDATE TransactionJournalDetail SET
					AccountId = @AccountId,
					Amount = @Amount,
					CrDeAmount = @CrDeAmt
				WHERE TxDetailId = @MyTxDetailId - 1
			END
		END
		
		ELSE IF @MySourceDocOrder = 100 --OBE
		BEGIN
			-- Step 1: Ensure cost is positive
			SET @Price = ABS(@Price)
			-- Step 2: Set closing quantity to physical count
			SET @CloQty = @Qty
			-- Step 3: Recalculate inventory value
			SET @InventoryValue = ROUND(@Qty * @Price, 6)
			-- Step 4: Update average cost to new price
			SET @AvgCost = @Price
			-- Step 5: Calculate adjustment amount (for accounting)
			SET @Amount = @InventoryValue - @LInventoryValue
			--@INV RECALC
			SET @Amount = ISNULL(@Amount, 0);
			IF @Amount = 0
				SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
			ELSE --IF @IsDebit = 1 --@INV
				SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
			UPDATE TransactionJournalDetail SET 
				--Qty = @CloQty, 
				--Price = @Price,
				--ExtTotal = NULL,
				ClosingQty = @CloQty,
				AverageCost = @AvgCost,
				InventoryQty = @InventoryValue,
				Amount = @Amount,
				CrDeAmount = @CrDeAmt
			WHERE TxDetailId = @MyTxDetailId	
				
			--PAIRED ACCOUNT (@OBE) RECALC
			--SELECT @AccountId=AccountId FROM TransactionJournalDetail WHERE TxDetailId=@MyTxDetailId-1
			--SELECT TOP 1 @MyTxDetailId = TxDetailId, @ChartAcctCode = ChartAcctCode
			--FROM TransactionJournalDetail WHERE TxDetailId < @MyTxDetailId ORDER BY TxDetailId DESC
			IF @Amount = 0
				SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
			ELSE --IF @IsDebit = 0  -- @OBE
				SET @CrDeAmt = CASE WHEN @Amount > 0 THEN ABS(@Amount) ELSE -ABS(@Amount) END;
			UPDATE TransactionJournalDetail SET 
				--Price = @LAvgCost,
				--ChartAcctCode = @NewAdjChartAcctCode,
				Amount = @Amount,
				CrDeAmount = @CrDeAmt
			WHERE TxDetailId = @MyTxDetailId - 1
		END
		SET @LCloQty = @CloQty
		SET @LAvgCost = @AvgCost
		SET @LInventoryValue = @InventoryValue
		
		SET @RowNum += 1
	END
	DROP TABLE #QAVTable;
END

