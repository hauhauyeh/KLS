SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-07-21 DROPSHIP-RECEIPT-STAGE: expose linked SO receipt stage for PO Manager bill conversion guard.
-- 2026-07-13 DROPSHIP-SOREF: project linked SO reference for PO Manager badge.
-- 2026-07-13 PO-TOTALS: show order total and bill total in PO Manager.
-- 2026-08-09 PO-DS-SEQ: return drop-ship chain label for PO Manager badge.
-- 2026-08-12 PO-DS-CUSTOMER: return linked drop-ship customer name for PO Manager badge.
-- 2026-08-12 PO-SEARCH: expand PO Manager search refs with parameterized search values.
-- 2026-08-12 PO-DS-CUSTOMER-FILTER: filter PO Manager by exact linked drop-ship customer id.
-- 2026-08-28 PO-ORDERED-FILTER: Filterby='ordered' lists Ordered PO rows only.
CREATE OR ALTER PROCEDURE [dbo].[PurchaseOrder_GetAllList] -- EXEC dbo.PurchaseOrder_GetAllList @Pageno=1,@Pagesize=50,@Search=NULL,@StartDate=NULL,@EndDate=NULL,@VendorId=NULL,@EmpId=NULL,@Filterby=NULL,@Id=NULL,@SortField=NULL,@SortOrder=NULL,@IsCount=0,@DropShipSalesCustomerId=NULL,@TotalCount=NULL
	
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
	@DropShipSalesCustomerId INT,
	@TotalCount INT OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX);
	DECLARE @IsAdmin BIT
	DECLARE @S NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@Search)), N'');
	DECLARE @SearchNumber INT = TRY_CONVERT(INT, @S);

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
		dsseq.DropShipChainLabel,
		dss.StageId AS DropShipSalesStageId,
		dss.CustPONumber AS DropShipSalesCustPONumber,
		dss.ShipId AS DropShipSalesCustomerId,
		dsp.PayeeName AS DropShipSalesCustomerName,

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
	LEFT JOIN Payee AS dsp ON dsp.PayeeId = dss.ShipId
	OUTER APPLY (
		SELECT RootSalesNumber = COALESCE(dss.ParentSalesNumber, dss.SalesNumber)
	) dsroot
	OUTER APPLY (
		SELECT DropShipChainLabel =
			CASE
				WHEN ISNULL(p.IsDropShip, 0) = 1
				 AND p.DropShipSalesId IS NOT NULL
				 AND dss.SalesId IS NOT NULL
				 AND seq.ChainIndex > 0
				THEN CONCAT(
					seq.ChainIndex,
					CASE
						WHEN seq.ChainIndex % 100 BETWEEN 11 AND 13 THEN ''th''
						WHEN seq.ChainIndex % 10 = 1 THEN ''st''
						WHEN seq.ChainIndex % 10 = 2 THEN ''nd''
						WHEN seq.ChainIndex % 10 = 3 THEN ''rd''
						ELSE ''th''
					END
				)
				ELSE NULL
			END
		FROM (
			SELECT ChainIndex = COUNT(1)
			FROM dbo.Sales AS chainRow
			WHERE dsroot.RootSalesNumber IS NOT NULL
			  AND (chainRow.SalesNumber = dsroot.RootSalesNumber
				   OR chainRow.ParentSalesNumber = dsroot.RootSalesNumber)
			  AND (
					CASE WHEN chainRow.SalesNumber = dsroot.RootSalesNumber THEN 0 ELSE 1 END
					< CASE WHEN dss.SalesNumber = dsroot.RootSalesNumber THEN 0 ELSE 1 END
					OR (
						CASE WHEN chainRow.SalesNumber = dsroot.RootSalesNumber THEN 0 ELSE 1 END
						= CASE WHEN dss.SalesNumber = dsroot.RootSalesNumber THEN 0 ELSE 1 END
						AND chainRow.SalesNumber <= dss.SalesNumber
					)
			  )
		) seq
	) dsseq
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

	IF @DropShipSalesCustomerId IS NOT NULL
		SET @Qry += ' AND dss.ShipId = @DropShipSalesCustomerId'

	IF @S IS NOT NULL
		SET @Qry += ' AND (
			p.VendorDocNumber LIKE ''%'' + @S + ''%''
			OR p.ContainerNumber LIKE ''%'' + @S + ''%''
			OR p.FactorPO LIKE ''%'' + @S + ''%''
			OR dss.CustPONumber LIKE ''%'' + @S + ''%''
			OR (@SearchNumber IS NOT NULL AND p.PurchaseNumber = @SearchNumber)
			OR (@SearchNumber IS NOT NULL AND dss.SalesNumber = @SearchNumber)
		)'

	IF @StartDate is not null
		SET @Qry += ' AND p.ArrivalDate>='''+CONVERT(VARCHAR,@StartDate)+''''

	IF @EndDate is not null
		SET @Qry += ' AND p.ArrivalDate<='''+CONVERT(VARCHAR,@EndDate)+''''

	IF @Filterby is not null
	BEGIN
		IF @Filterby='ordered'
			SET @Qry += ' AND p.StageId=1'
		ELSE IF @Filterby='unpaid'
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
		EXEC sp_executesql
			@Qry,
			N'@S NVARCHAR(50), @SearchNumber INT, @DropShipSalesCustomerId INT, @RCount int OUTPUT',
			@S = @S,
			@SearchNumber = @SearchNumber,
			@DropShipSalesCustomerId = @DropShipSalesCustomerId,
			@RCount = @TotalCount OUTPUT
		RETURN
	END

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	ELSE
		SET @Qry+=' ORDER BY p.EnterDate DESC,p.PurchaseNumber DESC'
	
	SET @Qry += ' OFFSET '+ CONVERT(VARCHAR(100),(@PageSize * (@Pageno - 1))) +' ROWS 
	FETCH NEXT '+ CONVERT(VARCHAR(100),@Pagesize) +' ROWS ONLY '

	EXEC sp_executesql
		@Qry,
		N'@S NVARCHAR(50), @SearchNumber INT, @DropShipSalesCustomerId INT',
		@S = @S,
		@SearchNumber = @SearchNumber,
		@DropShipSalesCustomerId = @DropShipSalesCustomerId

END




