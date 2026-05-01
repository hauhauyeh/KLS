CREATE OR ALTER PROCEDURE [dbo].[InventoryAdj_Insert]
	@AdjId INT,
	@AdjDate DATE,
	@AdjType NVARCHAR(50),
	@OpenClose NVARCHAR(50),
	@Notes NVARCHAR(255),
	@EmpId INT,
	@NewAdjId INT OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
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
	INSERT INTO [dbo].[InventoryAdjDetail]
			([AdjId]
			,[ItemId]
			,[NewQty]
			,[QtyDiffer]
			,[NewPrice]
			,[Notes])
	SELECT 
			@AdjId,
			ItemId,
			NewQty,
			QtyDiffer,
			NewPrice,
			Notes
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
	DECLARE @NewPrice DECIMAL(18,2)
	DECLARE @QtyDiff DECIMAL(18,2)
	DECLARE @SrcDetailId INT
	
	DECLARE @MyTable TABLE (
		AutoId INT IDENTITY(1,1) PRIMARY KEY,
		ItemId INT,
		NewQty DECIMAL(18,2),
		QtyDiffer DECIMAL(18,2),
		NewPrice DECIMAL(18,2),
		SrcDetailId INT
	)
	CREATE TABLE #InvTxDetail
	(
		AutoId int IDENTITY(1,1),
		TxId INT,
		AccountId INT,
		ItemId INT,
		Qty DECIMAL(18,2),
		Price DECIMAL(18,2),
		BillQty DECIMAL(18,2),
		Amount DECIMAL(18,2),
		CrDeAmount DECIMAL(18,2),
		SrcDetailId INT
	)
	
	INSERT INTO	@MyTable(
		ItemId,
		NewQty,
		QtyDiffer,
		NewPrice,
		SrcDetailId)
	SELECT
		ItemId,
		NewQty,
		QtyDiffer,
		NewPrice,
		AdjDetailId
	FROM InventoryAdjDetail WHERE AdjId=@AdjId
	
	/*
		Insert MyTable To TransactionJournalDetail
		Adjustment Account
		Inventory Account
	*/
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
	WHILE @RowNum <= @MaxRow
	BEGIN
		
		SELECT
			@ItemId=ItemId,
			@NewQty=NewQty,
			@NewPrice=NewPrice,
			@QtyDiff=QtyDiffer,
			@SrcDetailId=SrcDetailId
		FROM @MyTable WHERE AutoId = @RowNum
		--IF @OpenClose='Intermediate'
		--	SET @NewQty+=ISNULL(@SoldQty,0)
		SET @CrDeAmount=0
		SELECT @LCloQty=LCloQty,@LAvgCost=LAvgCost,@LInventoryValue=LInventoryValue 
		FROM @LastInvTable WHERE ItemId=@ItemId
						
		If @AdjType='Q'
		BEGIN
			SET @NewPrice = @LAvgCost
			--IF @NewQty = @LCloQty GOTO NEXT_ITEM
			SET @Amount = ROUND(((@NewQty-@LCloQty) * @NewPrice),2)
						
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
	
		IF @AdjType='V'
		BEGIN
			SET @NewQty=@LCloQty
			--IF @NewPrice = @LAvgCost GOTO NEXT_ITEM
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
			--IF (@NewQty = @LCloQty) AND (@NewPrice = @LAvgCost) GOTO NEXT_ITEM
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
		IF @AdjType='A'
		BEGIN	
			SET @Amount = ROUND((@NewQty * @NewPrice),2)
			--SET @Amount = ROUND((@NewQty * @LAvgCost),2)
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
			
		IF @AdjType='N'
		BEGIN	
			SET @NewPrice = @LAvgCost
			SET @Amount = ROUND((@NewQty * @NewPrice),2)
			SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'
			INSERT INTO #InvTxDetail
			   ([TxId]
			   ,[AccountId] 
			   ,[ItemId]
			   ,[Qty]
			   ,[Price]
			   ,[SrcDetailId])
			VALUES
			   (@TxId
			   ,@AccountId
			   ,@ItemId
			   ,@NewQty
			   ,@NewPrice
			   ,@SrcDetailId)
			INSERT INTO #InvTxDetail
			   ([TxId]
			   ,[AccountId]
			   ,[ItemId]
			   ,[Qty]
			   ,[Price]
			   ,[SrcDetailId])
			VALUES
			   (@TxId
			   ,@InvAccountId
			   ,@ItemId
			   ,@NewQty
			   ,@NewPrice
			   ,@SrcDetailId)
		END
		If @AdjType='QR'
		BEGIN
			SET @NewPrice = @LAvgCost
			--IF @NewQty = @LCloQty GOTO NEXT_ITEM
			SET @Amount = ROUND((@NewQty * @NewPrice),2)
				
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
					,[CrDeAmount]
					,[SrcDetailId])
				VALUES
				   (@TxId
				   ,@AccountId
				   ,@ItemId
				   ,@NewQty
				   ,@NewPrice
				   ,NULL
				   ,ABS(@Amount)
				   ,@CrDeAmount
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
NEXT_ITEM:
		SET @RowNum += 1
	END
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
	
	EXEC Recalc_AfterInsert @TxId,@AdjDate
END
