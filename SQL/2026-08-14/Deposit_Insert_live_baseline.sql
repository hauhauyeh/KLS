CREATE PROCEDURE [dbo].[Deposit_Insert]

	@TFId INT,
	@TFDate DATE,
	--@FromAccountId INT,
	@ToAccountId INT,
	@TransferAmount DECIMAL(18,2),
	@CashbackAccountId INT,
	@CashbackAmount DECIMAL(18,2),
	@CCFeeAmount DECIMAL(18,2),
	@RoundingOff DECIMAL(18,2),
	@EmpId INT,
	@NewTFId INT OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	
	DECLARE @TxId BIGINT
	DECLARE @OldTFId INT=@TFId
	DECLARE @TFNumber INT
	DECLARE @CrDeAmt DECIMAL(18,2)=0;
	DECLARE @AccountCode NVARCHAR(50);
	DECLARE @SourceDocType NVARCHAR(50)='Deposit'
	DECLARE @SourceDocOrder int;
	DECLARE @TotalSelectedAmt DECIMAL(18,2)
	DECLARE @IsEdit BIT=0
	DECLARE @Amount DECIMAL(18,2)
	DECLARE @CreatedAt DATETIME = GETUTCDATE()
	DECLARE @UpdatedAt DATETIME
	DECLARE @FromAccountId INT

	SELECT @FromAccountId=AccountId FROM Account WHERE AccountCode='@UF'

	CREATE TABLE #TempDeposit
	(
		TxId BIGINT,
		AccountId INT,
		AccountCode NVARCHAR(50),
		Amount DECIMAL(18,2),
		CrDeAmount DECIMAL(18,2)
	)

	EXEC [Get_SourceDocOrder] @SourceDocType,@SourceDocOrder OUTPUT

	IF @TFId > 0
    BEGIN
        SET @IsEdit = 1;
		SET @UpdatedAt = GETUTCDATE();

        SELECT @TFNumber = TFNumber, @CreatedAt = CreatedAt FROM TransferFund
        WHERE TFId = @TFId;

        DELETE FROM TransferFund
        WHERE TFId = @TFId;
    END
    ELSE
        SET @TFNumber = NEXT VALUE FOR dbo.Seq_TFNumber;

	--check if current applied customer payment is already deposited or not
	DECLARE @custpmtcount INT

	SELECT @custpmtcount=COUNT(CustomerPaymentId) FROM CustomerPayment WHERE CustomerPaymentId IN (SELECT CustomerPaymentId FROM TempTransferFund WHERE EmpId=@EmpId AND IsApplied=1) AND IsLocked=1

	IF @custpmtcount>0
	BEGIN
		RAISERROR('Some payment is already deposited which you select for this deposit.',16,1);
		RETURN;
	END

	INSERT INTO [dbo].[TransferFund]
			([TFNumber]
			,[TFDate]
			,[TFType]
			,[FromAccountId]
			,[ToAccountId]
			,[TransferAmount]	
			,[CashbackAmount]
			,[CashbackAccountId]
			,[CCFeeAmount]
			,[RoundingOff]
			,[CreatedAt]
			,[UpdatedAt])
	VALUES (@TFNumber,
			@TFDate,
			'DEPOSIT',
			@FromAccountId,
			@ToAccountId,
			@TransferAmount,
			@CashbackAmount,
			@CashbackAccountId,
			@CCFeeAmount,
			@RoundingOff,
			@CreatedAt,
			@UpdatedAt)

	SELECT @TFId = SCOPE_IDENTITY();

	INSERT INTO [dbo].[TransferFundDetail]
			([TFId]
			,[CustomerPaymentId]
			,[DepositAmount]
			,[Notes])
	SELECT  @TFId,
			CustomerPaymentId,
			DepositAmount,
			Notes
	FROM TempTransferFund WHERE EmpId=@EmpId AND TFId=(CASE WHEN @IsEdit=0 THEN 0 ELSE @OldTFId END) 
	AND IsApplied=1 

	
	--Update isdeposite filed in CustPmt table
	UPDATE CustomerPayment SET IsLocked=1 
	FROM CustomerPayment AS c INNER JOIN TransferFundDetail AS td ON c.CustomerPaymentId=td.CustomerPaymentId
	WHERE td.TFId=@TFId

	SELECT @TotalSelectedAmt=ISNULL(SUM(DepositAmount),0) FROM TransferFundDetail WHERE TFId=@TFId

	--Insert into TransactionJournal

	INSERT INTO [dbo].[TransactionJournal]
			([TxDate]
			,[TxTime]
			,[SourceDocOrder]
			,[SourceDocType]
			,[SourceDocNumber])
	VALUES (@TFDate,
			GETUTCDATE(),
			@SourceDocOrder,
			@SourceDocType,
			@TFNumber)

	SELECT @TxId = SCOPE_IDENTITY();

	--UF decrease 
	SET @AccountCode='@UF'
	SET @Amount=@TotalSelectedAmt*-1
	EXEC Fn_Adjust_CrDeAmount @AccountCode,@Amount,@CrDeAmt OUTPUT

	INSERT INTO #TempDeposit
			([TxId]
			,[AccountCode]	
			,[Amount]
			,[CrDeAmount])
	VALUES
			(@TxId
			,@AccountCode	
			,@Amount
			,@CrDeAmt)

	IF @TransferAmount!=0
	BEGIN
		--====Bank increase 	
		EXEC Fn_Adjust_CrDeAmount @ToAccountId,@TransferAmount,@CrDeAmt OUTPUT

		INSERT INTO #TempDeposit
				([TxId]
				,[AccountId]	
				,[Amount]
				,[CrDeAmount])
		VALUES
				(@TxId
				,@ToAccountId	
				,@TransferAmount
				,@CrDeAmt)
	END

	IF @CashbackAmount!=0 AND @CashbackAmount IS NOT NULL
	BEGIN
		 --====CASHBACKACCT increase 
		EXEC Fn_Adjust_CrDeAmount @CashbackAccountId,@CashbackAmount,@CrDeAmt OUTPUT

		INSERT INTO #TempDeposit
				([TxId]
				,[AccountId]	
				,[Amount]
				,[CrDeAmount])
		VALUES
				(@TxId
				,@CashbackAccountId	
				,@CashbackAmount
				,@CrDeAmt)
	END
		
	IF @CCFeeAmount!=0 AND @CCFeeAmount IS NOT NULL
	BEGIN
		--====ECCDF increase 
		SET @AccountCode='@ECCDF'	
		EXEC Fn_Adjust_CrDeAmount @AccountCode,@CCFeeAmount,@CrDeAmt OUTPUT

		INSERT INTO #TempDeposit
				([TxId]
				,[AccountCode]	
				,[Amount]
				,[CrDeAmount])
		VALUES
				(@TxId
				,@AccountCode	
				,@CCFeeAmount
				,@CrDeAmt)
	END

	IF @RoundingOff!=0 AND @RoundingOff IS NOT NULL
	BEGIN
		--====ERO increase 
		SET @AccountCode='@ERO'
		EXEC Fn_Adjust_CrDeAmount @AccountCode,@RoundingOff,@CrDeAmt OUTPUT

		INSERT INTO #TempDeposit
				([TxId]
				,[AccountCode]
				,[Amount]
				,[CrDeAmount])
		VALUES
				(@TxId
				,@AccountCode	
				,@RoundingOff
				,@CrDeAmt)
	END

	-- Update account code based on account id
	UPDATE t SET t.AccountCode = a.AccountCode 
	FROM #TempDeposit AS t INNER JOIN Account AS a 
	ON a.AccountId = t.AccountId 
	WHERE t.AccountId IS NOT NULL AND t.AccountCode IS NULL;

	INSERT INTO TransactionJournalDetail
			([TxId]
			,[AccountId]
			,[Amount]
			,[CrDeAmount])
	SELECT [TxId]
			,a.[AccountId]
			,[Amount]
			,[CrDeAmount]
	FROM #TempDeposit AS t INNER JOIN Account AS a ON t.AccountCode=a.AccountCode 
	ORDER BY TxId

	DELETE TempTransferFund where EmpId=@EmpId 

	-- call RecalcQAV after insert
	EXEC Recalc_AfterInsert @TxId,@TFDate

	SET @NewTFId=@TFId
END

