CREATE OR ALTER PROCEDURE [dbo].[InventoryAdj_PartialUpdate]
	@AdjId INT,
	@AdjDate DATE,
	@AdjType NVARCHAR(50),
	@Notes NVARCHAR(255),
	@EmpId INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
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
	DECLARE @TempInvTable TABLE (
		[AutoId] INT IDENTITY(1,1) NOT NULL,
		[ItemId] INT NULL,
		[NewQty] DECIMAL(18,2) NULL,
		[QtyDiffer] DECIMAL(18,2) NULL,
		[NewPrice] DECIMAL(18,2) NULL,
		[Notes] NVARCHAR(255) NULL,
		[ChangeStatus] varchar(1) NULL,
		[SrcDetailId] int NULL
	)
	INSERT INTO @TempInvTable
	SELECT
      ItemId
      ,NewQty
      ,QtyDiffer
      ,NewPrice
      ,Notes
	  ,ChangeStatus
	  ,AdjDetailId
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
		@NoteDetail=Notes
		FROM @TempInvTable 
		WHERE AutoId=@RowNum
		IF @ChangeStatus='I'
		BEGIN
			INSERT INTO [dbo].[InventoryAdjDetail]
				([AdjId]
				,[ItemId]
				,[NewQty]
				,[QtyDiffer]
				,[NewPrice]
				,[Notes])
			VALUES(
				@AdjId
				,@ItemId
				,@NewQty
				,@QtyDiff
				,@NewPrice
				,@Notes)
			SET @SrcDetailId=SCOPE_IDENTITY();
			IF @AdjType IN ('Q','V','B','QR')
			BEGIN
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@IINVG'
				INSERT INTO TransactionJournalDetail
					([TxId]
					,[AccountId]
					,[ItemId]		
					,[SourceDetailId])
				VALUES
				   (@TxId
				   ,@AccountId
				   ,@ItemId 
				   ,@SrcDetailId)	
				INSERT INTO TransactionJournalDetail
				   ([TxId]
				   ,[AccountId]
				   ,[ItemId]
				   ,[Qty]
				   ,[Price] 
				   ,[SourceDetailId])
				VALUES
				   (@TxId
				   ,@InvAccountId
				   ,@ItemId
				   ,@NewQty
				   ,@NewPrice 
				   ,@SrcDetailId)
			END
			ELSE IF @AdjType IN ('N')
			BEGIN
				SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@COGS'
				INSERT INTO TransactionJournalDetail
					([TxId]
					,[AccountId]
					,[ItemId]		
					,[SourceDetailId])
				VALUES
				   (@TxId
				   ,@AccountId
				   ,@ItemId 
				   ,@SrcDetailId)	
				INSERT INTO TransactionJournalDetail
				   ([TxId]
				   ,[AccountId]
				   ,[ItemId]
				   ,[Qty]
				   ,[Price] 
				   ,[SourceDetailId])
				VALUES
				   (@TxId
				   ,@InvAccountId
				   ,@ItemId
				   ,@NewQty
				   ,@NewPrice 
				   ,@SrcDetailId)
			END
			ELSE IF @AdjType IN ('A')
			BEGIN
				INSERT INTO TransactionJournalDetail
				   ([TxId]
				   ,[AccountId]
				   ,[ItemId]
				   ,[Qty]
				   ,[Price] 
				   ,[SourceDetailId])
				VALUES
				   (@TxId
				   ,@InvAccountId
				   ,@ItemId
				   ,@NewQty
				   ,@NewPrice 
				   ,@SrcDetailId)
			END
		END
		ELSE IF @ChangeStatus='U'
		BEGIN
			UPDATE InventoryAdjDetail 
			SET NewQty=@NewQty,QtyDiffer=@QtyDiff,NewPrice=@NewPrice,Notes=@NoteDetail 
			WHERE AdjDetailId=@SrcDetailId
			UPDATE TransactionJournalDetail SET Qty=@NewQty,Price=@NewPrice
			WHERE TxId=@TxId AND SourceDetailId=@SrcDetailId AND AccountId=@InvAccountId
		END
		ELSE IF @ChangeStatus='D'
		BEGIN
			DELETE FROM InventoryAdjDetail WHERE AdjDetailId=@SrcDetailId
			DELETE FROM TransactionJournalDetail WHERE SourceDetailId=@SrcDetailId AND TxId=@TxId
		END
		SET @RowNum+=1
	END
	UPDATE InventoryAdj SET AdjType=@AdjType,AdjDate=@AdjDate,Notes=@Notes,UpdatedAt=GETUTCDATE() 
	WHERE AdjId=@AdjId
	UPDATE TransactionJournal SET TxDate=@AdjDate,TxTime=GETUTCDATE() WHERE TxId=@TxId
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
