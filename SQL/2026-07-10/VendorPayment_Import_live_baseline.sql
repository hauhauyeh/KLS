USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- VendorPayment_Import -- LIVE BASELINE captured 2026-07-10
-- Unmodified definition as it exists in production, for diff
-- and rollback. Do not edit.
-- ============================================================

CREATE PROCEDURE [dbo].[VendorPayment_Import] --[PayNow_Import] 'C:\Users\Admin\Downloads\CC (1).xlsx'

	@PaymentMethod NVARCHAR(50),
	@FromAccountId INT,
	@FilePath NVARCHAR(255),
	@EmpId INT,
	@TxCount INT OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX)

	--EXEC sp_configure 'Show Advanced Options', 1;
	--RECONFIGURE;

	--EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
	--RECONFIGURE;

	---- Enable ACE provider options
	--EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'AllowInProcess', 1;
	--EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'DynamicParameters', 1;

	DECLARE @PayNowExcel AS TABLE (
		[AutoId] INT IDENTITY(1,1),
		[EnterDate] DATE NULL,
		[ArrivalDate] DATE NULL,
		[PayeeId] INT NULL,
		[PayeeName] nvarchar(255) NULL,
		[PmtRefNum] nvarchar(255) NULL,
		[AccountCode] nvarchar(50) NULL,
		[AccountName] nvarchar(255) NULL,
		[PmtAmount] DECIMAL(18,2) NULL,
		[Note] nvarchar(255) NULL,
		[BankDate] DATE NULL,
		[Batch] INT NOT NULL
	)

	DECLARE @BatchExcel AS TABLE(
		[BatchRowNum] INT IDENTITY(1,1),
		[Batch] INT NOT NULL
	)

	--DECLARE @MonthlyExcel AS TABLE(
	--	[MonthlyId] INT IDENTITY(1,1),
	--	[PmtDate] DATE NULL,
	--	[PayeeId] INT NULL,
	--	[PmtMethod] nvarchar(50) NULL,
	--	[PmtRefNum] nvarchar(255) NULL
	--)
	
	SET @Qry='SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; Database='+CONVERT(NVARCHAR(255),@FilePath)+''', [Sheet1$]);'

	INSERT INTO @PayNowExcel
	EXEC (@Qry)

	--IF @IsMonthlyEntry=1
	--BEGIN
	--	INSERT INTO @MonthlyExcel(PmtDate,PayeeId,PmtMethod,PmtRefNum)
	--	SELECT DISTINCT ArrivalDate,PayeeId,PmtMethod,PmtRefNum FROM @PayNowExcel ORDER BY ArrivalDate
	--END

	INSERT INTO @BatchExcel
	SELECT Batch FROM @PayNowExcel GROUP BY Batch ORDER BY Batch

	DECLARE @MaxRow INT
	DECLARE @RowNum INT=1
	DECLARE @PayeeId INT
	DECLARE @PaymentDate DATE
	DECLARE @PmtRefNum nvarchar(100)
	DECLARE @PaymentAmount DECIMAL(18,2)
	DECLARE @Note nvarchar(255)
	DECLARE @BankDate DATE
	DECLARE @AcctCode nvarchar(50)
	DECLARE @BillQty DECIMAL(18,2)
	DECLARE @NewVendorPaymentId int
	DECLARE @Batch int
	DECLARE @IsMultiRow INT

	SELECT @MaxRow=COUNT(*) FROM @BatchExcel

	WHILE @RowNum <= @MaxRow
	BEGIN
		SELECT @Batch=Batch FROM @BatchExcel WHERE BatchRowNum=@RowNum

		SELECT top(1)
			@PayeeId=PayeeId,
			@PaymentDate=ArrivalDate,
			@PmtRefNum=PmtRefNum,	
			@BankDate=BankDate,
			@Note=Note
		FROM @PayNowExcel WHERE Batch=@Batch--AutoId=@RowNum

		SELECT @PaymentAmount=SUM(PmtAmount) FROM @PayNowExcel WHERE Batch=@Batch

		SELECT @IsMultiRow=COUNT(*) FROM @PayNowExcel WHERE Batch=@Batch

		IF @IsMultiRow>1
			SET @Note=null

		--IF @PmtAmount<0
		--	SET @BillQty=-1
		--ELSE
		--	SET @BillQty=1

		DELETE FROM TempPurchase WHERE EmpId=@EmpId AND PayeeId=@PayeeId

		INSERT INTO [dbo].[TempPurchase]
			   ([EmpId]
			   ,[PayeeId]
			   ,[PurchaseId]
			   ,[LineType]
			   ,[AccountId]
			   ,[OrdQty0]
			   ,[ShipQty]
			   ,[BillQty]
			   ,[BillPrice]
			   ,[OrdQty1]
			   ,[ReceiveQty]
			   ,[FinalQty]
			   ,[FinalPrice]
			   ,[Notes])
		SELECT @EmpId
				,@PayeeId
				,0
				,'A'
				,(SELECT AccountId FROM Account WHERE AccountCode=p.AccountCode)
				,CASE WHEN PmtAmount<0 THEN -1 ELSE 1 END
				,CASE WHEN PmtAmount<0 THEN -1 ELSE 1 END
				,CASE WHEN PmtAmount<0 THEN -1 ELSE 1 END
				,ABS(PmtAmount)
				,CASE WHEN PmtAmount<0 THEN -1 ELSE 1 END
				,CASE WHEN PmtAmount<0 THEN -1 ELSE 1 END
				,CASE WHEN PmtAmount<0 THEN -1 ELSE 1 END
				,ABS(PmtAmount)
				,Note
		FROM @PayNowExcel p WHERE Batch=@Batch

		EXEC [VendorPayment_InsertPayNow] 0,@PayeeId,@PaymentDate,@PaymentMethod,@FromAccountId,@PmtRefNum,@PaymentAmount,@Note,@EmpId,@NewVendorPaymentId OUTPUT

		IF @BankDate IS NOT NULL
		BEGIN
			UPDATE VendorPayment SET IsLocked=1,MailDate=@BankDate,BankDate=@BankDate 
			WHERE VendorPaymentId=@NewVendorPaymentId
		END

		SET @RowNum+=1
	END

	SET @TxCount=@MaxRow;
END


GO
