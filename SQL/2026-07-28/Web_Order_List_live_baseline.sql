-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[Web_Order_List]

	@Pageno int,
	@Pagesize int,
	@Search nvarchar(50),
	@StartDate date,
	@EndDate date,
	@PayeeId int,
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(50),
	@IsCount bit,
	@TotalCount int OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
 
	DECLARE @Qry NVARCHAR(MAX);
	DECLARE @Today DATE = GETDATE();
 
	IF @IsCount=1
		SET @Qry='SELECT @RCount=COUNT(s.SalesNumber)'
	ELSE
		SET @Qry='SELECT s.SalesId,
    s.SalesNumber,
    s.SalesDate,
    s.ShipDate,
    s.ShipRoute,
    s.ShipId,
	s.SubTotal,
	s.TaxTotal,
    s.SalesTotal,
    s.Instruction,
    s.AmountDue,
    s.CustPONumber,
    s.RouteOrder,
    s.IsLocked,
    s.IsLoadSeparate,
    p.PayeeName,
    p.City,
    s.StageId,
    ss.StageName,
    psCalc.PaymentStatusId,
    ps.PaymentStatusName,
    s.ShippingCarrierId,
    sc.PayeeName AS ShippingCarrierName,
    t.TermName,
    p.IsCreditHold,
    p.PayeePastDue,
    p.Balance,
    p.MaxInvoiceAgingDays'
 
	SET @Qry += ' FROM Sales AS s INNER JOIN Payee AS p on p.PayeeId=s.ShipId
	LEFT JOIN Customer c ON c.PayeeId = p.PayeeId
	LEFT JOIN SalesStage ss ON ss.StageId = s.StageId
	LEFT JOIN Payee sc ON sc.PayeeId = s.ShippingCarrierId
	LEFT JOIN Term t ON t.TermId = s.TermId
	CROSS APPLY (
    SELECT 
        CASE 
            -- Positive invoice (normal sale)
            WHEN s.SalesTotal > 0 THEN
                CASE 
                    WHEN s.PaymentApplied = 0 THEN 5  -- Unpaid
                    WHEN (s.PaymentApplied + ISNULL(s.DiscountApplied, 0)) <  s.SalesTotal THEN 6  -- Partially Paid
                    WHEN (s.PaymentApplied + ISNULL(s.DiscountApplied, 0)) =  s.SalesTotal THEN 7  -- Paid
                    WHEN (s.PaymentApplied + ISNULL(s.DiscountApplied, 0)) >  s.SalesTotal THEN 8  -- Over Paid
                END

            -- Zero invoice amount
            WHEN s.SalesTotal = 0 THEN
                CASE 
                    WHEN (s.PaymentApplied + ISNULL(s.DiscountApplied, 0)) = 0 THEN 5  -- Unpaid (nothing to pay, nothing applied)
                    WHEN (s.PaymentApplied + ISNULL(s.DiscountApplied, 0)) > 0 THEN 8  -- Over Paid (money/discount but no sales total)
                END

            -- Negative invoice (credit note)
            WHEN s.SalesTotal < 0 THEN
                CASE 
                    WHEN s.PaymentApplied = 0 THEN 9                           -- Credit
                    WHEN ABS(s.PaymentApplied) <  ABS(s.SalesTotal) THEN 10    -- Credit - Partial
                    WHEN ABS(s.PaymentApplied) >= ABS(s.SalesTotal) THEN 11    -- Credit - Settled
                END
        END AS PaymentStatusId
	) AS psCalc LEFT JOIN PaymentStatus AS ps ON ps.PaymentStatusId = psCalc.PaymentStatusId
		WHERE p.PayeeType=''c'''

	
	SET @Qry += ' AND s.ShipId='+CONVERT(varchar,@PayeeId)+''

	IF @Search is not null	
		SET @Qry += ' AND (s.SalesNumber='+@Search+' or s.SalesTotal='+@Search+')'
 
	IF @StartDate is not null
		SET @Qry += ' AND s.ShipDate>='''+CONVERT(VARCHAR,@StartDate)+''''

	IF @EndDate is not null
		SET @Qry += ' AND s.ShipDate<='''+CONVERT(VARCHAR,@EndDate)+''''

	IF @IsCount=1
	BEGIN
		EXEC sp_executesql @Qry,N'@RCount int OUTPUT',@RCount=@TotalCount OUTPUT
		RETURN
	END

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	ELSE IF @StartDate IS NOT NULL
		SET @Qry += ' ORDER BY s.ShipRoute,s.RouteOrder,p.PayeeName,s.SalesNumber'
	ELSE
		SET @Qry += ' ORDER BY s.SalesNumber DESC'
	
	SET @Qry += ' OFFSET '+ CONVERT(VARCHAR(100),(@PageSize * (@Pageno - 1))) +' ROWS 
	FETCH NEXT '+ CONVERT(VARCHAR(100),@Pagesize) +' ROWS ONLY '
 
	EXEC (@Qry)
END
