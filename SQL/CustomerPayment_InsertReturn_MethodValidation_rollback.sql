SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[CustomerPayment_InsertReturn]
	
	@CustomerPaymentId INT,
	@ReturnType NVARCHAR(50),
	@ReturnDate DATE,
	@FeeAccountId INT,
	@FeeAmount DECIMAL(18,2),	--This is for bank
	@NSFFee DECIMAL(18,2),
	@EmpId INT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @SalesId INT;
	DECLARE @PaymentAmount DECIMAL(18,2);
	DECLARE @PayeeId INT;

	DECLARE @TxId BIGINT;
	DECLARE @CrDeAmount DECIMAL(18,2) = 0;	
	DECLARE @AccountId INT;
	DECLARE @BankAccountId INT;
	DECLARE @Amount DECIMAL(18,2);

	DECLARE @PaymentNumber INT

	SELECT @BankAccountId=T.ToAccountId 
	FROM TransferFund AS T INNER JOIN TransferFundDetail AS TD ON T.TFId=TD.TFId 
	WHERE CustomerPaymentId=@CustomerPaymentId

	IF @BankAccountId IS NULL
	BEGIN
		RAISERROR('This payment is not deposit yet so you can not return it.',16,1);	
		RETURN;
	END

	UPDATE CustomerPayment SET 
	ReturnType=@ReturnType,
	ReturnDate=@ReturnDate,
	FeeAccountId=@FeeAccountId,
	FeeAmount=@FeeAmount,
	IsReturned=1,
	UpdatedAt=GETUTCDATE()
	WHERE CustomerPaymentId=@CustomerPaymentId

	EXEC [CustomerPayment_UpdateSales] @CustomerPaymentId,1

	UPDATE CustomerPaymentDetail SET PaymentApplied=0,PaymentDiscount=0,ShortDiscount=0,OtherDiscount=0 
	WHERE CustomerPaymentId=@CustomerPaymentId

	SELECT @PaymentNumber=PaymentNumber,
	@PayeeId=PayeeId,
	@PaymentAmount=PaymentAmount
	FROM CustomerPayment WHERE CustomerPaymentId=@CustomerPaymentId

	DECLARE @DocOrder INT
	DECLARE @DocType NVARCHAR(50)='Incoming Check Returned'
	EXEC [Get_SourceDocOrder] @DocType,@DocOrder OUTPUT

	INSERT INTO [dbo].[TransactionJournal]
           ([TxDate]
		   ,[TxTime]
           ,[SourceDocOrder]
           ,[SourceDocType]
           ,[SourceDocNumber])
	VALUES
           (@ReturnDate
		   ,GETUTCDATE()
		   ,@DocOrder
		   ,@DocType
		   ,@PaymentNumber)

	SELECT @TxId = SCOPE_IDENTITY();

	INSERT INTO [dbo].[TransactionJournalDetail]
			([TxId]
			,[AccountId]
			,[PayeeId]
			,[Amount]
			,[CrDeAmount])
	SELECT @TxId
			,td.AccountId
			,td.PayeeId
			,td.Amount*-1
			,td.CrDeAmount*-1
	FROM TransactionJournal As t INNER JOIN TransactionJournalDetail AS td on t.TxId=td.TxId
	INNER JOIN Account a ON a.AccountId=td.AccountId
	WHERE t.SourceDocNumber=@PaymentNumber AND t.SourceDocType='Customer Payment' 
	and a.AccountCode!='@UF'

	SET @Amount = @PaymentAmount*-1
	EXEC Fn_Adjust_CrDeAmount @BankAccountId,@Amount,@CrDeAmount OUTPUT

	INSERT INTO [dbo].[TransactionJournalDetail]
			([TxId]
			,[AccountId]
			,[PayeeId]
			,[Amount]
			,[CrDeAmount])
	VALUES
			(@TxId
			,@BankAccountId
			,@PayeeId
			,@Amount
			,@CrDeAmount)

	IF @FeeAmount!=0
	BEGIN
		SET @Amount = @FeeAmount*-1
		EXEC Fn_Adjust_CrDeAmount @BankAccountId,@Amount,@CrDeAmount OUTPUT		

		INSERT INTO [dbo].[TransactionJournalDetail]
				([TxId]
				,[AccountId]
				,[PayeeId]
				,[Amount]
				,[CrDeAmount])
		VALUES
				(@TxId
				,@BankAccountId
				,@PayeeId
				,@Amount
				,@CrDeAmount)

		EXEC Fn_Adjust_CrDeAmount @FeeAccountId,@FeeAmount,@CrDeAmount OUTPUT		

		INSERT INTO [dbo].[TransactionJournalDetail]
				([TxId]
				,[AccountId]
				,[PayeeId]
				,[Amount]
				,[CrDeAmount])
		VALUES
				(@TxId
				,@FeeAccountId
				,@PayeeId
				,@FeeAmount
				,@CrDeAmount)
	END

	EXEC Recalc_AfterInsert @TxId,@ReturnDate

	IF @NSFFee>0
	BEGIN
		DELETE FROM TempSales WHERE EmpId=@EmpId AND PayeeId=@PayeeId

		SELECT @AccountId=AccountId FROM Account WHERE AccountCode='@IOT'

		IF @AccountId IS NULL
			RETURN

		INSERT INTO [dbo].[TempSales]
           ([EmpId]
           ,[SalesId]
           ,[PayeeId]
           ,[LineType]
           ,[AccountId]
           ,[OrdQty]
           ,[ShipQty]
           ,[BillQty]
           ,[UnitPrice]
           ,[Notes]
		   ,[FactorToBase])
		VALUES
           (@EmpId
           ,0
           ,@PayeeId
		   ,'A'
           ,@AccountId
           ,1
           ,1
           ,1
           ,@NSFFee
           ,'NSFFee'
		   ,1)

		EXEC [Sales_Insert] 0,@PayeeId,@ReturnDate,null,'NSFFee',3,@EmpId,@SalesId OUTPUT

		UPDATE CustomerPayment SET ReturnSalesId=@SalesId WHERE CustomerPaymentId=@CustomerPaymentId
	END
END
GO
