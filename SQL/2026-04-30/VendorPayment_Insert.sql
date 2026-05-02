

CREATE PROCEDURE [dbo].[VendorPayment_Insert]



	@VendorPaymentId INT,

	@PayeeId INT,

	@PaymentDate DATE,

	@PaymentType NVARCHAR(100),

	@PaymentMethod NVARCHAR(50),

	@ReferenceId NVARCHAR(100),

	@FromAccountId INT,

	@PaymentAmount DECIMAL(18,2),

	@Notes NVARCHAR(255),	

	@EmpId INT,

	@NewPaymentId INT OUTPUT

AS

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.

	SET NOCOUNT ON;



    -- Insert statements for procedure here

	

	DECLARE @VendorPaymentNumber INT=0;

	DECLARE @TxId BIGINT;

	DECLARE @CrDeAmount DECIMAL(18,2)=0;

	DECLARE @AccountId INT;

	DECLARE @Amount DECIMAL(18,2)

	DECLARE @SourceDocType NVARCHAR(100);

	DECLARE @SourceDocOrder INT;

	DECLARE @TotalPaymentApplied DECIMAL(18,2);

	DECLARE @IsRedeposit BIT=0

	DECLARE @MailDate DATE

	DECLARE @IsReturn1 BIT=0

	DECLARE @IsReturn2 BIT=0

	DECLARE @PrintDate DATE

	DECLARE @BankDate DATE

	DECLARE @IsLocked BIT=0

	DECLARE @CreatedAt DATETIME = GETUTCDATE()

	DECLARE @UpdatedAt DATETIME



	IF @VendorPaymentId > 0

    BEGIN

		SET @UpdatedAt = GETUTCDATE();



		SELECT @VendorPaymentNumber=PaymentNumber,

		@IsReturn1=IsReturn1,

		@IsRedeposit=IsRedeposit,

		@IsReturn2=IsReturn2,

		@PrintDate=PrintDate,

		@MailDate=MailDate,

		@BankDate=BankDate,

		@IsLocked=IsLocked,

		@CreatedAt=CreatedAt

		FROM VendorPayment WHERE VendorPaymentId=@VendorPaymentId



		IF @IsRedeposit=0 --if already Redeposited then dont delete otherwise delete

			DELETE FROM VendorPayment WHERE VendorPaymentId=@VendorPaymentId

    END

    ELSE

        SET @VendorPaymentNumber = NEXT VALUE FOR dbo.Seq_VendorPaymentNumber;



	-- Keep explicit refund companion payment types intact.
	-- Only coerce normal vendor disbursements into Bill Payment / Bill CCard.
	IF @PaymentType NOT IN ('Vendor Refund','Customer Refund')

	BEGIN

		IF @PaymentMethod = 'CREDIT CARD'

			SET @PaymentType = 'Bill CCard'

		ELSE

			SET @PaymentType = 'Bill Payment' 

	END



	IF @PaymentMethod = 'HANDWRITE CHECK'

		SET @MailDate=@PaymentDate



	SET @SourceDocType=@PaymentType

	EXEC [Get_SourceDocOrder] @SourceDocType,@SourceDocOrder OUTPUT



	--check if current applied bill is already paid or not

	DECLARE @BillCount INT



	SELECT @BillCount=COUNT(PurchaseId) FROM Purchase AS p 

	WHERE PurchaseId IN (SELECT PurchaseId FROM TempVendorPayment WHERE EmpId=@EmpId AND PayeeId=@PayeeId AND IsApplied=1 AND ABS(PaymentApplied+DiscountApplied)>ABS(p.AmountDue))



	IF @BillCount>0

	BEGIN

		RAISERROR('Some bill is already paid which you applied for this payment.',16,1);

		RETURN;

	END



	---To restrict duplicate payment refnum

	IF @VendorPaymentId = 0 AND @PaymentMethod='CHECK'

		EXEC [Get_CheckNumber] @FromAccountId,@ReferenceId OUTPUT



	IF @IsRedeposit=1 --if already ReDeposited just insert Tx entry

	BEGIN

		DELETE FROM VendorPaymentDetail WHERE VendorPaymentId=@VendorPaymentId

		GOTO ifRedeposited

	END





	INSERT INTO [dbo].[VendorPayment]

			([PaymentNumber]

			,[PaymentType]

			,[PayeeId]

			,[PaymentDate]

			,[PaymentMethod]

			,[ReferenceId]

			,[FromAccountId]

			,[PaymentAmount]

			,[Notes]	

			,[MailDate]

			,[BankDate]

			,[IsReturn1]

			,[IsRedeposit]

			,[IsReturn2]

			,[PrintDate]

			,[IsLocked]

			,[CreatedAt]

			,[UpdatedAt])

	VALUES

			(@VendorPaymentNumber,

			@PaymentType,

			@PayeeId,

			@PaymentDate,

			@PaymentMethod,

			@ReferenceId,

			@FromAccountId,

			@PaymentAmount,

			@Notes,

			@MailDate,

			@BankDate,

			@IsReturn1,

			@IsRedeposit,

			@IsReturn2,

			@PrintDate,

			@IsLocked,

			@CreatedAt,

			@UpdatedAt)



	SELECT @VendorPaymentId = SCOPE_IDENTITY();



ifRedeposited: --if already Redeposited then don't delete first Tx and insert 2 Tx



	INSERT INTO [dbo].[VendorPaymentDetail]

			([VendorPaymentId]

			,[PurchaseId]

			,[PaymentApplied]

			,[DiscountApplied])

    SELECT 

			@VendorPaymentId

			,PurchaseId

			,PaymentApplied

			,DiscountApplied

	FROM TempVendorPayment WHERE EmpId=@EmpId and PayeeId=@PayeeId AND IsApplied=1 



	DECLARE @DiscountApplied DECIMAL(18,2);



	EXEC [VendorPayment_UpdatePurchase] @VendorPaymentId,0



	--Insert into TransactionJournal

	

	DECLARE @AcctTable AS Table(

		Id INT IDENTITY(1,1),

		AccountCode NVARCHAR(50),

		AccountId INT

	)



	INSERT INTO @AcctTable(AccountCode) VALUES('@AP')

	INSERT INTO @AcctTable(AccountCode) VALUES('@CRP')

	INSERT INTO @AcctTable(AccountCode) VALUES('@UF')

	INSERT INTO @AcctTable(AccountCode) VALUES('@IDR')



	UPDATE t SET t.AccountId=a.AccountId

	FROM @AcctTable AS t INNER JOIN Account AS a ON t.AccountCode=a.AccountCode



	INSERT INTO [dbo].[TransactionJournal]

			([TxDate]

			,[TxTime]

			,[SourceDocOrder]

			,[SourceDocType]

			,[SourceDocNumber]

			,[Notes]

			,[BankDate]

			,[IsLocked])

		VALUES

			(@PaymentDate

			,GETUTCDATE()

			,@SourceDocOrder

			,@SourceDocType

			,@VendorPaymentNumber

			,@Notes

			,@BankDate

			,@IsLocked)



	SELECT @TxId = SCOPE_IDENTITY();



	-- Refund payout path:
	-- this is the issued-refund companion vendor payment created from customer refund reserve.
	--
	-- Business rule for this path:
	-- - do not use AP detail logic
	-- - do not use VendorPaymentDetail at all
	-- - payout accounting should be:
	--     CRP debit
	--     BANK credit
	--
	-- Why:
	-- the customer-payment side already created the refund reserve liability.
	-- This vendor-payment side is only the actual cash-out step.
	IF @PaymentType='Customer Refund'
	BEGIN
		-- Refund line 1:
		-- debit Customer Refund Payable to release the reserve when cash goes out.
		SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@CRP'
		SET @Amount=ABS(ISNULL(@PaymentAmount,0))*-1
		EXEC Fn_Adjust_CrDeAmount @AccountId,@Amount,@CrDeAmount OUTPUT

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

				,@CrDeAmount)
	END
	ELSE
	BEGIN
		-- Normal vendor-payment path:
		-- AP debit still comes from the applied vendor detail rows.
		SELECT @TotalPaymentApplied=ISNULL(SUM(PaymentApplied)+SUM(DiscountApplied),0)

		FROM VendorPaymentDetail WHERE VendorPaymentId=@VendorPaymentId



		--====For Accounts Payable account	Debit	

		SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@AP'

		SET @Amount=@TotalPaymentApplied*-1



		EXEC Fn_Adjust_CrDeAmount @AccountId,@Amount,@CrDeAmount OUTPUT



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

				,@CrDeAmount)
	END



	--====For Accounts from user select credit	

	DECLARE @IsAccountDebit BIT

	DECLARE @X DECIMAL(18,2)



	--Insert into TxJournalDetail 'ANY BANK ACCOUNT USER SELECT'

	SET @AccountId=@FromAccountId

	SELECT @IsAccountDebit=IsAccountDebit FROM Account AS a WHERE AccountId=@AccountId



	IF @IsAccountDebit=1

		SET @X = @PaymentAmount*-1

	ELSE

		SET @X = @PaymentAmount



	-- Bank/cash side:
	-- - Customer Refund uses the selected bank/cash account directly
	-- - Vendor Refund keeps its older UF exception behavior

	IF @PaymentType='Vendor Refund' AND @PaymentMethod!='CREDIT CARD'

		SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@UF'



	EXEC Fn_Adjust_CrDeAmount @AccountId,@X,@CrDeAmount OUTPUT



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

			,@X

			,@CrDeAmount)



	--If there is Discount Received from vendor than

	SELECT @DiscountApplied = ISNULL(SUM(DiscountApplied),0) FROM VendorPaymentDetail 

	WHERE VendorPaymentId= @VendorPaymentId



	IF @DiscountApplied != 0

	BEGIN

		--====For Accounts Discount Received account	credit	

		SELECT @AccountId=AccountId FROM @AcctTable WHERE AccountCode='@IDR'



		EXEC Fn_Adjust_CrDeAmount @AccountId,@DiscountApplied,@CrDeAmount OUTPUT

	

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

				,@DiscountApplied

				,@CrDeAmount)

	END

	



	IF @PaymentType='Vendor Refund' AND @PaymentMethod!='CREDIT CARD'

	BEGIN

		DECLARE @CustomerPaymentNumber INT

		SET @CustomerPaymentNumber = NEXT VALUE FOR dbo.Seq_CustomerPaymentNumber;



		INSERT INTO [dbo].[CustomerPayment]

           ([PaymentNumber]

           ,[PaymentType]

           ,[PayeeId]

           ,[PaymentDate]

           ,[PaymentMethod]

           ,[FromAccountId]

           ,[ReferenceId]

           ,[PaymentAmount]

           ,[Notes]

           ,[VendorPaymentId]

		   ,[CreatedAt])

		VALUES

           (@CustomerPaymentNumber

           ,@PaymentType

           ,@PayeeId

           ,@PaymentDate

           ,@PaymentMethod

           ,NULL

           ,@ReferenceId

           ,ABS(@PaymentAmount)

           ,@Notes

           ,@VendorPaymentId

		   ,@CreatedAt)

	END



	DELETE TempVendorPayment WHERE EmpId=@EmpId AND PayeeId=@PayeeId 



	-- call RecalcQAV after insert

	EXEC Recalc_AfterInsert @TxId,@PaymentDate



	SET @NewPaymentId=@VendorPaymentId

END




