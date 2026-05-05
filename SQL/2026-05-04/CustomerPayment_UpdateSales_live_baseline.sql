CREATE PROCEDURE [dbo].[CustomerPayment_UpdateSales]
	
	@CustomerPaymentId INT,
	@IsDelete BIT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @SalesId INT;
	DECLARE @SalesTotal DECIMAL(18,2);
	DECLARE @TotalPaymentApplied DECIMAL(18,2);
	DECLARE @TotalDiscountApplied DECIMAL(18,2);
	DECLARE @AmountDue DECIMAL(18,2);
	DECLARE @Aging INT;
	DECLARE @InvAging INT;
	DECLARE @PayeeId INT;
	DECLARE @ShipDate DATE;
	DECLARE @IsLocked BIT=0;
	DECLARE @IsCreditMemo INT;

	DECLARE @RowNum INT=1
	DECLARE @MaxRow INT

	CREATE TABLE #PmtDetail (
		AutoId INT IDENTITY(1,1) PRIMARY KEY,
		SalesId INT
	)
	INSERT INTO #PmtDetail (SalesId)
	SELECT SalesId FROM CustomerPaymentDetail
	WHERE CustomerPaymentId = @CustomerPaymentId AND IsCreditMemo=0
	ORDER BY PaymentDetailId

	SELECT @MaxRow = COUNT(AutoId) FROM #PmtDetail
 
	WHILE @RowNum <= @MaxRow
	BEGIN
		SELECT @SalesId=SalesId FROM #PmtDetail WHERE AutoId = @RowNum

		SELECT 
		@SalesTotal=ISNULL(SalesTotal,0),
		@PayeeId=ShipId,
		@ShipDate=ShipDate
		FROM Sales WHERE SalesId = @SalesId
 
		IF @IsDelete = 1
			SELECT 
			@TotalPaymentApplied = ISNULL(SUM(PaymentApplied), 0),
			@TotalDiscountApplied = ISNULL(SUM(DiscountApplied), 0) 
			FROM CustomerPaymentDetail WHERE CustomerPaymentId<>@CustomerPaymentId AND SalesId = @SalesId;
		ELSE
			SELECT 
			@TotalPaymentApplied = ISNULL(SUM(PaymentApplied), 0),
			@TotalDiscountApplied = ISNULL(SUM(DiscountApplied), 0) 
			FROM CustomerPaymentDetail WHERE SalesId = @SalesId;
		

		SET @AmountDue = @SalesTotal - @TotalPaymentApplied - @TotalDiscountApplied
 
		--Get Aging	
		EXEC Fn_Calc_Aging @ShipDate,@PayeeId,@AmountDue,@Aging OUTPUT,@InvAging OUTPUT
 
		SELECT @IsCreditMemo=COUNT(PaymentDetailId) FROM CustomerPaymentDetail 
		WHERE SalesId=@SalesId AND IsCreditMemo=1
 
		IF @IsCreditMemo>0
			SET @IsLocked=1
		ELSE
		BEGIN
			IF @AmountDue<>@SalesTotal
				SET @IsLocked=1
			ELSE
				SET @IsLocked=0
		END
	
		UPDATE Sales SET AmountDue=@AmountDue,
		PaymentApplied=@TotalPaymentApplied,
		DiscountApplied=@TotalDiscountApplied,
		IsLocked=@IsLocked,
		Aging=@Aging,
		InvoiceAging=@InvAging 
		WHERE SalesId=@SalesId
 
		EXEC [Payee_UpdateAging] @PayeeId,1
 
		SET @RowNum += 1
	END

END
