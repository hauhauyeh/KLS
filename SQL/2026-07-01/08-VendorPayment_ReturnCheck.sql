SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Fix: WHERE PurchaseId=PurchaseId → WHERE PurchaseId=@PurchaseId
-- Bug 5: column=column is always true, reads wrong ArrivalDate/PayeeId for Aging calc
-- Note: 0 records affected currently (ReturnCheck has never been used)

CREATE OR ALTER PROCEDURE [dbo].[VendorPayment_ReturnCheck]

	@VendorPaymentId INT,
	@ReturnType NVARCHAR(50),
	@ReturnDate DATE,
	@FeeAccountId INT,
	@FeeAmount DECIMAL(18,2),
	@IsRedeposit BIT

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @MaxRow INT
	DECLARE @RowNum INT=1
	DECLARE @FromBankId INT
	DECLARE @PaymentAmount DECIMAL(18,2)
	DECLARE @PayeeId INT

	DECLARE @PaymentNumber INT
	DECLARE @PurchaseId INT
	DECLARE @AmtApplied DECIMAL(18,2)
	DECLARE @DiscountApplied DECIMAL(18,2)
	DECLARE @TotalAmtApplied DECIMAL(18,2)
	DECLARE @TotalDiscount DECIMAL(18,2)
	DECLARE @PurchaseTotal DECIMAL(18,2)
	DECLARE @AmtDue DECIMAL(18,2)

	DECLARE @Aging INT=0;
	DECLARE @InvAging INT=0;
	DECLARE @ArrivalDate DATE;

	DECLARE @TxId BIGINT;
	DECLARE @TxDate DATE = @ReturnDate;
	DECLARE @CrDeAmt DECIMAL(18,2)=0;
	DECLARE @AccountId INT;
	DECLARE @Amount DECIMAL(18,2)

	DECLARE @DocOrder INT
	DECLARE @DocType NVARCHAR(50)='Outgoing Check Returned'
	EXEC [Get_SourceDocOrder] @DocType,@DocOrder OUTPUT

	SELECT @PaymentNumber=PaymentNumber FROM VendorPayment WHERE VendorPaymentId=@VendorPaymentId

	IF @IsRedeposit=1
	BEGIN
		UPDATE VendorPayment SET IsRedeposit=1 WHERE VendorPaymentId=@VendorPaymentId
		goto skip_deposit
	END

	SELECT @IsRedeposit=IsRedeposit,
	@FromBankId=FromAccountId,
	@PaymentAmount=PaymentAmount,
	@PayeeId=PayeeId
	FROM VendorPayment
	WHERE VendorPaymentId=@VendorPaymentId

	IF @IsRedeposit=0 --First time return
	BEGIN
		UPDATE VendorPayment SET IsReturn1=1,ReturnType1=@ReturnType,ReturnDate1=@ReturnDate,FeeAccountId1=@FeeAccountId,FeeAmount1=@FeeAmount WHERE VendorPaymentId=@VendorPaymentId
	END
	ELSE IF @IsRedeposit=1 --Second time return
	BEGIN
		UPDATE VendorPayment SET IsReturn2=1,ReturnType2=@ReturnType,ReturnDate2=@ReturnDate,FeeAccountId2=@FeeAccountId,FeeAmount2=@FeeAmount WHERE VendorPaymentId=@VendorPaymentId
	END

	-- UnApply payment
	DECLARE @MyTable TABLE (
		AutoId INT IDENTITY(1,1) PRIMARY KEY,
		PurchaseId INT,
		PaymentApplied DECIMAL(18,2),
		DiscountApplied DECIMAL(18,2)
	)

	INSERT INTO @MyTable(PurchaseId, PaymentApplied, DiscountApplied)
	SELECT PurchaseId, ISNULL(SUM(PaymentApplied),0),ISNULL(SUM(DiscountApplied),0)
	FROM VendorPaymentDetail
	WHERE VendorPaymentId=@VendorPaymentId
	GROUP BY PurchaseId

	SELECT @MaxRow = COUNT(AutoId) FROM @MyTable

	WHILE @RowNum <= @MaxRow
	BEGIN
		SELECT @PurchaseId=PurchaseId,@AmtApplied=PaymentApplied,@DiscountApplied=DiscountApplied
		FROM @MyTable WHERE AutoId=@RowNum

		SELECT @PurchaseTotal=ISNULL(PurchaseTotal,0),
		@TotalAmtApplied = ISNULL(PaymentApplied,0),
		@TotalDiscount=ISNULL(DiscountApplied,0)
		FROM Purchase WHERE PurchaseId = @PurchaseId

		SET @TotalAmtApplied = @TotalAmtApplied - @AmtApplied
		SET @TotalDiscount = @TotalDiscount - @DiscountApplied
		SET @AmtDue = @PurchaseTotal - @TotalAmtApplied - @TotalDiscount

		--Get Aging
		SELECT @PayeeId=PayeeId,@ArrivalDate=ArrivalDate FROM Purchase WHERE PurchaseId=@PurchaseId

		EXEC Fn_Calc_Aging @ArrivalDate,@PayeeId,@AmtDue,@Aging OUTPUT,@InvAging OUTPUT

		UPDATE Purchase SET AmountDue=@AmtDue,PaymentApplied=@TotalAmtApplied,DiscountApplied=@TotalDiscount,IsLocked=0,Aging=@Aging,InvoiceAging=@InvAging
		WHERE PurchaseId = @PurchaseId

		EXEC [Payee_UpdateAging] @PayeeId,0

		SET @RowNum += 1
	END

	UPDATE VendorPaymentDetail SET PaymentApplied=0,DiscountApplied=0 WHERE VendorPaymentId=@VendorPaymentId

	--Insert into TransactionJournal

	INSERT INTO [dbo].[TransactionJournal]
	       ([TxDate]
	       ,[TxTime]
	       ,[SourceDocOrder]
	       ,[SourceDocType]
	       ,[SourceDocNumber])
	VALUES
	       (@TxDate
		   ,GETUTCDATE()
		   ,@DocOrder
		   ,@DocType
		   ,@PaymentNumber)

	SELECT @TxId = SCOPE_IDENTITY();

	---DEC Bank
	SET @AccountId = @FromBankId
	EXEC Fn_Adjust_CrDeAmount @AccountId,@PaymentAmount,@CrDeAmt OUTPUT

	INSERT INTO [dbo].[TransactionJournalDetail]
			([TxId]
			,[AccountId]
			,[PayeeId]
			,[Amount]
			,[CrDeAmount])
		VALUES
			(@TxId
			,@AccountId
			,@PayeeId
			,@PaymentAmount
			,@CrDeAmt)

	---INC AP
	Select @AccountId = AccountId From Account Where AccountCode = '@AP'
	EXEC Fn_Adjust_CrDeAmount @AccountId,@PaymentAmount,@CrDeAmt OUTPUT

	INSERT INTO [dbo].[TransactionJournalDetail]
			([TxId]
			,[AccountId]
			,[PayeeId]
			,[Amount]
			,[CrDeAmount])
		VALUES
			(@TxId
			,@AccountId
			,@PayeeId
			,@PaymentAmount
			,@CrDeAmt)

	IF @FeeAmount>0
	BEGIN
		---DEC Bank with FeeAmt
		SET @AccountId = @FromBankId
		SET @Amount=@FeeAmount*-1
		EXEC Fn_Adjust_CrDeAmount @AccountId,@Amount,@CrDeAmt OUTPUT

		INSERT INTO [dbo].[TransactionJournalDetail]
				([TxId]
				,[AccountId]
				,[PayeeId]
				,[Amount]
				,[CrDeAmount])
			VALUES
				(@TxId
				,@AccountId
				,@PayeeId
				,@Amount
				,@CrDeAmt)

		---INC FeeExpenseAcct with FeeAmt
		SET @AccountId = @FeeAccountId
		EXEC Fn_Adjust_CrDeAmount @AccountId,@FeeAmount,@CrDeAmt OUTPUT

		INSERT INTO [dbo].[TransactionJournalDetail]
				([TxId]
				,[AccountId]
				,[PayeeId]
				,[Amount]
				,[CrDeAmount])
			VALUES
				(@TxId
				,@AccountId
				,@PayeeId
				,@FeeAmount
				,@CrDeAmt)
	END

	EXEC Recalc_AfterInsert @TxId,@TxDate

skip_deposit:

END
GO
