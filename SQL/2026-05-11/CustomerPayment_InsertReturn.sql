-- ============================================================
-- CustomerPayment_InsertReturn  (2026-05-11)
--
-- Change scope (this round, single edit):
--   Add a CustomerPayment header reset after the detail-row zero-out so the
--   cached PaymentApplied / UnappliedAmount / AsIncome columns stay consistent
--   with the zeroed CustomerPaymentDetail rows + the reopened Sales rows
--   produced by CustomerPayment_UpdateSales @cpid, 1. Without it, the
--   customer-payment-list and detail panel show the original applied amount
--   for a returned payment, even though Sales open balances and detail rows
--   already reflect the reversal.
--
-- Out of scope:
--   - CustomerPayment_DeleteReturn (intentional manual-reapply workflow per
--     the toast at customer-payment-list.component.ts:240).
--   - IsLocked semantics on returned payments.
--   - The reusable-credit pool: CustomerPayment_Inject already filters
--     IsReturned = 0, so this change does not affect cross-payment reuse.
--
-- Workflow:
--   - No CustomerPayment_InsertReturn_prev exists, so this is the first
--     formal workflow round. The rename guard below creates the one-time
--     _prev snapshot at the SQL level (alongside the live_baseline.sql
--     captured in KLS/SQL/2026-05-11/).
--   - The DROP IF EXISTS makes the script re-runnable within the round.
-- ============================================================

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'CustomerPayment_InsertReturn')
   AND NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'CustomerPayment_InsertReturn_prev')
    EXEC sp_rename 'CustomerPayment_InsertReturn', 'CustomerPayment_InsertReturn_prev';
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'CustomerPayment_InsertReturn')
    DROP PROCEDURE dbo.CustomerPayment_InsertReturn;
GO

CREATE PROCEDURE [dbo].[CustomerPayment_InsertReturn]

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
	DECLARE @PaymentMethod NVARCHAR(50);

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

	SELECT @PaymentMethod = UPPER(REPLACE(REPLACE(ISNULL(PaymentMethod, ''), '-', '_'), ' ', '_'))
	FROM CustomerPayment
	WHERE CustomerPaymentId = @CustomerPaymentId;

	IF @PaymentMethod NOT IN ('CHECK', 'HANDWRITE_CHECK', 'ACH', 'E_CHECK', 'CREDIT_CARD')
	BEGIN
		RAISERROR('This payment method can not be marked as returned.',16,1);
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

	-- 2026-05-11: keep the CustomerPayment header consistent with the zeroed
	-- CustomerPaymentDetail rows above and the reopened Sales rows updated by
	-- CustomerPayment_UpdateSales. Fixes a user-visible staleness in the
	-- customer-payment-list and detail panel after NSF return.
	-- This does NOT affect the reusable-credit pool used by CustomerPayment_Inject
	-- -- that pool already filters IsReturned = 0, so a returned payment is
	-- unavailable as a source regardless of these cached values.
	UPDATE dbo.CustomerPayment
	SET PaymentApplied = 0,
	    UnappliedAmount = ISNULL(PaymentAmount, 0),
	    AsIncome = NULL
	WHERE CustomerPaymentId = @CustomerPaymentId;

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

		EXEC [Sales_Insert]
			@SalesId = 0,
			@PayeeId = @PayeeId,
			@ShipDate = @ReturnDate,
			@ShipRoute = NULL,
			@Instruction = 'NSFFee',
			@StageId = 3,
			@EmpId = @EmpId,
			@NewSalesId = @SalesId OUTPUT,
			@DocType = 'SO',
			@ParentSalesNumber = NULL,
			@AllowNoParentOverride = 0

		UPDATE CustomerPayment SET ReturnSalesId=@SalesId WHERE CustomerPaymentId=@CustomerPaymentId
	END
END
GO
