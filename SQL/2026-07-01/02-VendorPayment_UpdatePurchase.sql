SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Fix: Add IsVoid=0 filter on both VPD sum branches + PayNow cursor after WHILE loop
-- Bug 2: Voided payments' VPD amounts (now preserved) must be excluded from sum
-- PayNow gap: PayNow has NO VPD rows, so the existing VPD cursor skips them entirely

CREATE OR ALTER PROCEDURE [dbo].[VendorPayment_UpdatePurchase]

	@VendorPaymentId INT,
	@IsDelete BIT

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @PurchaseId INT;
	DECLARE @PurchaseTotal DECIMAL(18,2);
	DECLARE @TotalPaymentApplied DECIMAL(18,2);
	DECLARE @TotalDiscountApplied DECIMAL(18,2);
	DECLARE @AmountDue DECIMAL(18,2);
	DECLARE @Aging INT;
	DECLARE @InvAging INT;
	DECLARE @PayeeId INT;
	DECLARE @ArrivalDate DATE;
	DECLARE @IsLocked BIT=0;

	DECLARE @RowNum INT=1
	DECLARE @MaxRow INT

	CREATE TABLE #PmtDetail (
		AutoId INT IDENTITY(1,1) PRIMARY KEY,
		PurchaseId INT
	)
	INSERT INTO #PmtDetail (PurchaseId)
	SELECT PurchaseId FROM VendorPaymentDetail
	WHERE VendorPaymentId = @VendorPaymentId
	ORDER BY PaymentDetailId

	SELECT @MaxRow = COUNT(AutoId) FROM #PmtDetail

	WHILE @RowNum <= @MaxRow
	BEGIN
		SELECT @PurchaseId=PurchaseId FROM #PmtDetail WHERE AutoId = @RowNum

		SELECT
		@PurchaseTotal=ISNULL(PurchaseTotal,0),
		@PayeeId=PayeeId,
		@ArrivalDate=ArrivalDate
		FROM Purchase WHERE PurchaseId = @PurchaseId

		-- FIX: Add IsVoid=0 filter to exclude voided payments from sum
		IF @IsDelete = 1
			SELECT
			@TotalPaymentApplied = ISNULL(SUM(vpd.PaymentApplied), 0),
			@TotalDiscountApplied = ISNULL(SUM(vpd.DiscountApplied), 0)
			FROM VendorPaymentDetail vpd
			INNER JOIN VendorPayment vp ON vp.VendorPaymentId = vpd.VendorPaymentId
			WHERE vpd.VendorPaymentId<>@VendorPaymentId AND vpd.PurchaseId = @PurchaseId AND vp.IsVoid = 0;
		ELSE
			SELECT
			@TotalPaymentApplied = ISNULL(SUM(vpd.PaymentApplied), 0),
			@TotalDiscountApplied = ISNULL(SUM(vpd.DiscountApplied), 0)
			FROM VendorPaymentDetail vpd
			INNER JOIN VendorPayment vp ON vp.VendorPaymentId = vpd.VendorPaymentId
			WHERE vpd.PurchaseId = @PurchaseId AND vp.IsVoid = 0;

		SET @AmountDue = @PurchaseTotal - @TotalPaymentApplied - @TotalDiscountApplied

		--Get Aging
		EXEC Fn_Calc_Aging @ArrivalDate,@PayeeId,@AmountDue,@Aging OUTPUT,@InvAging OUTPUT

		IF @AmountDue<>@PurchaseTotal
			SET @IsLocked=1
		ELSE
			SET @IsLocked=0

		UPDATE Purchase SET
		AmountDue=@AmountDue,
		PaymentApplied=@TotalPaymentApplied,
		DiscountApplied=@TotalDiscountApplied,
		IsLocked=@IsLocked,
		Aging=@Aging,
		InvoiceAging=@InvAging
		WHERE PurchaseId=@PurchaseId

		EXEC [Payee_UpdateAging] @PayeeId,0

		SET @RowNum += 1
	END

	-- FIX: PayNow cursor — PayNow has NO VPD rows, payment linked via PurchaseDetail.VendorPaymentId
	-- Find purchases linked to this VendorPaymentId through PurchaseDetail but NOT through VPD
	DECLARE @PayNowPurchaseId INT, @PayNowCalcTotal DECIMAL(18,2);
	DECLARE curPayNow CURSOR LOCAL FAST_FORWARD FOR
		SELECT DISTINCT pd.PurchaseId
		FROM PurchaseDetail pd
		WHERE pd.VendorPaymentId = @VendorPaymentId
		  AND pd.PurchaseId NOT IN (SELECT PurchaseId FROM #PmtDetail);
	OPEN curPayNow;
	FETCH NEXT FROM curPayNow INTO @PayNowPurchaseId;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [Purchase_CalcTotalAndPercent] @PayNowPurchaseId, @PayNowCalcTotal OUTPUT;
		-- CalcTotalAndPercent doesn't set IsLocked — update it here
		UPDATE Purchase SET IsLocked = CASE WHEN AmountDue <> PurchaseTotal THEN 1 ELSE 0 END
		WHERE PurchaseId = @PayNowPurchaseId;
		FETCH NEXT FROM curPayNow INTO @PayNowPurchaseId;
	END
	CLOSE curPayNow;
	DEALLOCATE curPayNow;

END
GO
