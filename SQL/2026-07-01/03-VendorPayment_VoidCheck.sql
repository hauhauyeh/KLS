SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Fix: Remove VPD amount zeroing + add PayNow fallback for void journal amount
-- Bug 2: Stop zeroing VPD.PaymentApplied/DiscountApplied on void (use IsVoid flag instead)
-- PayNow journal gap: PayNow has NO VPD rows, so VPD sum = 0 — fallback to VendorPayment.PaymentAmount

CREATE OR ALTER PROCEDURE [dbo].[VendorPayment_VoidCheck]

	@VendorPaymentId INT

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @VendorPaymentNumber INT;
	DECLARE @PaymentMethod NVARCHAR(50)
	DECLARE @PayeeId INT;
	DECLARE @FromAccountId INT
	DECLARE @TotalPaymentApplied DECIMAL(18,2)

	DECLARE @TxId BIGINT;
	DECLARE @TxDate DATE=GETDATE()
	DECLARE @CrDeAmount DECIMAL(18,2)=0;

	SELECT @VendorPaymentNumber=PaymentNumber,
	@PaymentMethod=PaymentMethod,
	@PayeeId=PayeeId,
	@TxDate=PaymentDate,
	@FromAccountId=FromAccountId
	FROM VendorPayment WHERE VendorPaymentId=@VendorPaymentId

	IF @PaymentMethod!='CHECK' AND @PaymentMethod!='HANDWRITE CHECK'
	BEGIN
		RAISERROR('You can only void CHECK and HANDWRITE CHECK',16,1);
		RETURN;
	END

	DECLARE @AccountId INT;
	DECLARE @SourceDocType NVARCHAR(50)='Outgoing Check Void'
	DECLARE @SourceDocOrder INT
	EXEC [Get_SourceDocOrder] @SourceDocType,@SourceDocOrder OUTPUT

	DECLARE @MyTable TABLE (
		AutoId INT IDENTITY(1,1) PRIMARY KEY,
		PurchaseNum INT,
		PmtApplied MONEY,
		DiscountApplied MONEY
	)

	UPDATE VendorPayment SET IsVoid=1 WHERE VendorPaymentId=@VendorPaymentId

	SELECT @TotalPaymentApplied=ISNULL(SUM(PaymentApplied)+SUM(DiscountApplied),0)
	FROM VendorPaymentDetail WHERE VendorPaymentId=@VendorPaymentId

	-- FIX: PayNow fallback — PayNow has NO VPD rows, use VendorPayment.PaymentAmount for journal entry
	IF @TotalPaymentApplied = 0
		SELECT @TotalPaymentApplied = ISNULL(PaymentAmount, 0)
		FROM VendorPayment WHERE VendorPaymentId = @VendorPaymentId

	-- FIX: REMOVED the following line that zeroed VPD amounts on void:
	-- UPDATE VendorPaymentDetail SET PaymentApplied=0,DiscountApplied=0 WHERE VendorPaymentId=@VendorPaymentId
	-- VPD amounts are now preserved; IsVoid=0 filter in sum queries handles exclusion

	EXEC [VendorPayment_UpdatePurchase] @VendorPaymentId,0

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
			,@SourceDocOrder
			,@SourceDocType
			,@VendorPaymentNumber)

	SELECT @TxId = SCOPE_IDENTITY();

	--For Accounts Payable account	credit
	SELECT @AccountId=AccountId FROM Account WHERE AccountCode='@AP'
	EXEC Fn_Adjust_CrDeAmount @AccountId,@TotalPaymentApplied,@CrDeAmount OUTPUT

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
			,@TotalPaymentApplied
			,@CrDeAmount)

	--For user select bank account  credit
	EXEC Fn_Adjust_CrDeAmount @FromAccountId,@TotalPaymentApplied,@CrDeAmount OUTPUT

	INSERT INTO [dbo].[TransactionJournalDetail]
			([TxId]
			,[AccountId]
			,[PayeeId]
			,[Amount]
			,[CrDeAmount])
		VALUES
			(@TxId
			,@FromAccountId
			,@PayeeId
			,@TotalPaymentApplied
			,@CrDeAmount)

	EXEC Recalc_AfterInsert @TxId,@TxDate
END
GO
