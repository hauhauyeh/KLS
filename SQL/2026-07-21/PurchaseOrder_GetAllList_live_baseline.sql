-- 2026-07-13 DROPSHIP-SOREF: project linked SO reference for PO Manager badge.
-- 2026-07-13 PO-TOTALS: show order total and bill total in PO Manager.
CREATE   PROCEDURE [dbo].[PurchaseOrder_GetAllList] --[PurchaseOrder_GetAllList] 1,50,null,null,null,null,null,null,null,null,null
	
	@Pageno int,
	@Pagesize int,
	@Search nvarchar(50),
	@StartDate date,
	@EndDate date,
	@VendorId int,
	@EmpId int,
	@Filterby nvarchar(50),
	@Id int,
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(50),
	@IsCount bit,	
	@TotalCount INT OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX);
	DECLARE @IsAdmin BIT

	SELECT @IsAdmin=r.IsAdmin FROM SystemUser as s inner join SystemRole as r on s.SystemRoleId=r.SystemRoleId
	WHERE PayeeId=@EmpId

	IF @IsCount=1
		SET @Qry='SELECT @RCount=COUNT(distinct p.PurchaseId)'
	ELSE
		SET @Qry='SELECT distinct
		v.PayeeName,
		p.PurchaseId,
		p.PurchaseNumber,
		p.StageId,
		pst.StageName,
		p.PayeeId,
		PurchaseDate,
		EnterDate,
		ArrivalDate,
		InvoiceDate,
		VendorDocNumber,
		p.FactorPO,
		ContainerNumber,
		(
			SELECT ISNULL(SUM(ROUND(ISNULL(pd.OrdQty0, 0) * ISNULL(pd.BillPrice, 0), 2)), 0)
			FROM dbo.PurchaseDetail pd
			WHERE pd.PurchaseId = p.PurchaseId
		) AS OrderTotal,
		VendorTotal,
		PurchaseTotal,
		p.AmountDue,
		p.Notes,
		p.IsLocked,
		IsFreightOnly,
		FreightTotal,			
		ImportCommission,
		PalletCount,
		CustomDutyTotal,
		psCalc.PaymentStatusId,
		ps.PaymentStatusName,
		p.IsDropShip,
		p.DropShipSalesId,
		dss.SalesNumber AS DropShipSalesNumber,
		dss.CustPONumber AS DropShipSalesCustPONumber,

		CASE 
        WHEN EXISTS (
            SELECT 1 FROM PurchaseDetail pd
            WHERE pd.PurchaseId = p.PurchaseId AND pd.LineType = ''I''
              AND pd.ItemId IS NOT NULL
        ) THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
		END AS IsNormalPurchase,
		CASE 
        WHEN EXISTS (
            SELECT 1 FROM PurchaseDetail pd
            WHERE pd.PurchaseId = p.PurchaseId
              AND pd.VendorPaymentId IS NOT NULL
        ) THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
		END AS IsPayNow'

	SET @Qry += ' FROM Purchase AS p INNER JOIN Payee AS v ON p.PayeeId = v.PayeeId
	INNER JOIN Vendor AS vp ON vp.PayeeId = v.PayeeId
	LEFT JOIN PurchaseStage AS pst ON pst.StageId = p.StageId
	LEFT JOIN Sales AS dss ON dss.SalesId = p.DropShipSalesId
		CROSS APPLY (
		SELECT 
			CASE
                -- Positive invoice (normal purchase)
                WHEN p.PurchaseTotal > 0 THEN
                    CASE
                        WHEN ISNULL(p.PaymentApplied, 0) = 0 THEN 5  -- Unpaid
                        WHEN (ISNULL(p.PaymentApplied, 0) + ISNULL(p.DiscountApplied, 0)) <  p.PurchaseTotal THEN 6  -- Partially Paid
                        WHEN (ISNULL(p.PaymentApplied, 0) + ISNULL(p.DiscountApplied, 0)) =  p.PurchaseTotal THEN 7  -- Paid
                        WHEN (ISNULL(p.PaymentApplied, 0) + ISNULL(p.DiscountApplied, 0)) >  p.PurchaseTotal THEN 8  -- Over Paid
                    END

                -- Zero invoice amount
                WHEN p.PurchaseTotal = 0 THEN
                    CASE
                        WHEN (ISNULL(p.PaymentApplied, 0) + ISNULL(p.DiscountApplied, 0)) = 0 THEN 5  -- Unpaid
                        WHEN (ISNULL(p.PaymentApplied, 0) + ISNULL(p.DiscountApplied, 0)) > 0 THEN 8  -- Over Paid
                    END

                -- Negative invoice (credit note)
                WHEN p.PurchaseTotal < 0 THEN
                    CASE
                        WHEN ISNULL(p.PaymentApplied, 0) = 0 THEN 9                           -- Credit
                        WHEN ABS(ISNULL(p.PaymentApplied, 0)) <  ABS(p.PurchaseTotal) THEN 10 -- Credit - Partial
                        WHEN ABS(ISNULL(p.PaymentApplied, 0)) >= ABS(p.PurchaseTotal) THEN 11 -- Credit - Settled
                    END
            END AS PaymentStatusId
		) AS psCalc LEFT JOIN PaymentStatus AS ps ON ps.PaymentStatusId = psCalc.PaymentStatusId
		WHERE p.IsStartFromPO=1'

	IF @Id is not null
		SET @Qry += ' AND p.PurchaseId='+convert(varchar,@Id)+''

	IF @IsAdmin=0
		SET @Qry+=' AND vp.IsVisibleToAdmin=0 '

	IF @VendorId is not null
		SET @Qry += ' AND p.PayeeId='+convert(varchar,@VendorId)+''

	IF @Search is not null
	BEGIN
		IF ISNUMERIC(@Search)=1
			SET @Qry += ' AND (p.PurchaseNumber='+@Search+' OR p.VendorDocNumber='''+@Search+''' OR p.ContainerNumber='''+@Search+''')'
		ELSE
			SET @Qry += ' AND (p.VendorDocNumber='''+@Search+''' OR p.ContainerNumber='''+@Search+''')'
	END

	IF @StartDate is not null
		SET @Qry += ' AND p.ArrivalDate>='''+CONVERT(VARCHAR,@StartDate)+''''

	IF @EndDate is not null
		SET @Qry += ' AND p.ArrivalDate<='''+CONVERT(VARCHAR,@EndDate)+''''

	IF @Filterby is not null
	BEGIN
		IF @Filterby='unpaid'
			SET @Qry += ' AND p.AmountDue!=0'
		ELSE IF @Filterby='paid'
			SET @Qry += ' AND p.AmountDue=0'
		ELSE IF @Filterby='overdue'
			SET @Qry += ' AND v.PayeePastDue!=0'
		--ELSE IF @Filterby='notcheckin'
		--	SET @Qry += ' AND p.IsCheckIn=0'
		ELSE IF @Filterby='notlink'
			SET @Qry += ' AND IsFreightOnly=1 and p.PurchaseId not in (select FreightBillId from FreightBillLink)'
	END
	
	IF @IsCount=1
	BEGIN
		EXEC sp_executesql @Qry,N'@RCount int OUTPUT',@RCount=@TotalCount OUTPUT
		RETURN
	END

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	ELSE
		SET @Qry+=' ORDER BY p.EnterDate DESC,p.PurchaseNumber DESC'
	
	SET @Qry += ' OFFSET '+ CONVERT(VARCHAR(100),(@PageSize * (@Pageno - 1))) +' ROWS 
	FETCH NEXT '+ CONVERT(VARCHAR(100),@Pagesize) +' ROWS ONLY '

	EXEC (@Qry)

END



