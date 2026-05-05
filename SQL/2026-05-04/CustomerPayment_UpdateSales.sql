CREATE OR ALTER PROCEDURE [dbo].[CustomerPayment_UpdateSales]
	
	@CustomerPaymentId INT,
	@IsDelete BIT
AS
BEGIN
	-- Keep NOCOUNT enabled so the calling layer does not receive stray row-count messages.
	SET NOCOUNT ON;

	-- Section 1. Declare working variables used during the per-sales refresh loop.
	DECLARE @SalesId INT;
	DECLARE @SalesTotal DECIMAL(18,2);
	DECLARE @TotalPaymentApplied DECIMAL(18,2);
	DECLARE @TotalDiscountApplied DECIMAL(18,2);
	DECLARE @AmountDue DECIMAL(18,2);
	DECLARE @Aging INT;
	DECLARE @InvAging INT;
	DECLARE @PayeeId INT;
	DECLARE @ShipDate DATE;
	DECLARE @IsLocked BIT = 0;
	DECLARE @IsCreditMemo INT;

	DECLARE @RowNum INT = 1;
	DECLARE @MaxRow INT;

	-- Section 2. Build the list of Sales rows that this payment touched.
	--
	-- 2026-05-04 historical live logic kept for reviewer comparison:
	-- INSERT INTO #PmtDetail (SalesId)
	-- SELECT SalesId FROM CustomerPaymentDetail
	-- WHERE CustomerPaymentId = @CustomerPaymentId AND IsCreditMemo=0
	-- ORDER BY PaymentDetailId
	--
	-- New rule:
	-- include consumed credit memo Sales rows too.
	-- If CustomerPaymentDetail says the payment touched the Sales row, that Sales row
	-- must be recalculated, whether it is a normal invoice or a credit memo document.
	CREATE TABLE #PmtDetail (
		AutoId INT IDENTITY(1,1) PRIMARY KEY,
		SalesId INT
	);

	INSERT INTO #PmtDetail (SalesId)
	SELECT DISTINCT SalesId
	FROM dbo.CustomerPaymentDetail
	WHERE CustomerPaymentId = @CustomerPaymentId
	  AND SalesId IS NOT NULL
	ORDER BY SalesId;

	SELECT @MaxRow = COUNT(AutoId) FROM #PmtDetail;
 
	-- Section 3. Recalculate each affected Sales row from committed CustomerPaymentDetail truth.
	WHILE @RowNum <= @MaxRow
	BEGIN
		SELECT @SalesId = SalesId
		FROM #PmtDetail
		WHERE AutoId = @RowNum;

		SELECT 
			@SalesTotal = ISNULL(SalesTotal, 0),
			@PayeeId = ShipId,
			@ShipDate = ShipDate
		FROM dbo.Sales
		WHERE SalesId = @SalesId;
 
		IF @IsDelete = 1
			SELECT 
				@TotalPaymentApplied = ISNULL(SUM(PaymentApplied), 0),
				@TotalDiscountApplied = ISNULL(SUM(DiscountApplied), 0)
			FROM dbo.CustomerPaymentDetail
			WHERE CustomerPaymentId <> @CustomerPaymentId
			  AND SalesId = @SalesId;
		ELSE
			SELECT 
				@TotalPaymentApplied = ISNULL(SUM(PaymentApplied), 0),
				@TotalDiscountApplied = ISNULL(SUM(DiscountApplied), 0)
			FROM dbo.CustomerPaymentDetail
			WHERE SalesId = @SalesId;

		SET @AmountDue = @SalesTotal - @TotalPaymentApplied - @TotalDiscountApplied;
 
		-- Section 4. Refresh aging values using the recalculated AmountDue.
		EXEC dbo.Fn_Calc_Aging @ShipDate, @PayeeId, @AmountDue, @Aging OUTPUT, @InvAging OUTPUT;
 
		-- Section 5. Refresh IsLocked.
		--
		-- A credit memo should stay locked once it participates in payment detail activity.
		-- A normal invoice or debit memo becomes locked once its due amount changes away from the original total.
		SELECT @IsCreditMemo = COUNT(PaymentDetailId)
		FROM dbo.CustomerPaymentDetail
		WHERE SalesId = @SalesId
		  AND IsCreditMemo = 1;
 
		IF @IsCreditMemo > 0
			SET @IsLocked = 1;
		ELSE
		BEGIN
			IF @AmountDue <> @SalesTotal
				SET @IsLocked = 1;
			ELSE
				SET @IsLocked = 0;
		END;
	
		UPDATE dbo.Sales
		SET AmountDue = @AmountDue,
			PaymentApplied = @TotalPaymentApplied,
			DiscountApplied = @TotalDiscountApplied,
			IsLocked = @IsLocked,
			Aging = @Aging,
			InvoiceAging = @InvAging
		WHERE SalesId = @SalesId;
 
		EXEC dbo.Payee_UpdateAging @PayeeId, 1;
 
		SET @RowNum += 1;
	END
END
