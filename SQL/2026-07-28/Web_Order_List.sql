SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- 2026-07-28 W1A: expose SalesDocNumber for web order list contract.
-- 2026-07-28 W4A: parameterize web order search and whitelist sort identifiers.
-- EXEC dbo.Web_Order_List @Pageno = 1, @Pagesize = 20, @Search = NULL, @StartDate = NULL, @EndDate = NULL, @PayeeId = 301919, @SortField = NULL, @SortOrder = NULL, @IsCount = 0, @TotalCount = 0
CREATE OR ALTER PROCEDURE [dbo].[Web_Order_List]

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
	DECLARE @SearchTrimmed NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@Search)), '');
	DECLARE @SearchInt INT = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@Search)), ''));
	DECLARE @SearchAmount DECIMAL(18, 2) = TRY_CONVERT(DECIMAL(18, 2), NULLIF(LTRIM(RTRIM(@Search)), ''));
	DECLARE @SortExpression NVARCHAR(100);
	DECLARE @SortDirection NVARCHAR(4);
	DECLARE @OffsetRows INT = @PageSize * (@Pageno - 1);
 
	IF @IsCount=1
		SET @Qry='SELECT @RCount=COUNT(s.SalesNumber)'
	ELSE
		SET @Qry='SELECT s.SalesId,
    s.SalesNumber,
    s.SalesDocNumber,
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

	
	SET @Qry += ' AND s.ShipId=@PayeeId'

	IF @SearchTrimmed IS NOT NULL
		SET @Qry += ' AND (
			(@SearchInt IS NOT NULL AND s.SalesNumber = @SearchInt)
			OR (@SearchAmount IS NOT NULL AND s.SalesTotal = @SearchAmount)
			OR s.SalesDocNumber LIKE ''%'' + @SearchTrimmed + ''%''
		)'
 
	IF @StartDate is not null
		SET @Qry += ' AND s.ShipDate>=@StartDate'

	IF @EndDate is not null
		SET @Qry += ' AND s.ShipDate<=@EndDate'

	IF @IsCount=1
	BEGIN
		EXEC sp_executesql
			@Qry,
			N'@PayeeId INT, @SearchTrimmed NVARCHAR(50), @SearchInt INT, @SearchAmount DECIMAL(18, 2), @StartDate DATE, @EndDate DATE, @RCount INT OUTPUT',
			@PayeeId = @PayeeId,
			@SearchTrimmed = @SearchTrimmed,
			@SearchInt = @SearchInt,
			@SearchAmount = @SearchAmount,
			@StartDate = @StartDate,
			@EndDate = @EndDate,
			@RCount = @TotalCount OUTPUT
		RETURN
	END

	SET @SortField = NULLIF(LTRIM(RTRIM(@SortField)), '');
	SET @SortOrder = UPPER(NULLIF(LTRIM(RTRIM(@SortOrder)), ''));
	SET @SortDirection = CASE WHEN @SortOrder = 'ASC' THEN 'ASC' ELSE 'DESC' END;
	SET @SortExpression = CASE @SortField
		WHEN 'SalesNumber' THEN 's.SalesNumber'
		WHEN 'SalesDocNumber' THEN 's.SalesDocNumber'
		WHEN 'SalesDate' THEN 's.SalesDate'
		WHEN 'ShipDate' THEN 's.ShipDate'
		WHEN 'ShipRoute' THEN 's.ShipRoute'
		WHEN 'RouteOrder' THEN 's.RouteOrder'
		WHEN 'PayeeName' THEN 'p.PayeeName'
		WHEN 'SalesTotal' THEN 's.SalesTotal'
		WHEN 'AmountDue' THEN 's.AmountDue'
		WHEN 'StageName' THEN 'ss.StageName'
		WHEN 'PaymentStatusName' THEN 'ps.PaymentStatusName'
		ELSE NULL
	END;

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+ISNULL(@SortExpression, 's.SalesNumber')+' '+@SortDirection
	ELSE IF @StartDate IS NOT NULL
		SET @Qry += ' ORDER BY s.ShipRoute,s.RouteOrder,p.PayeeName,s.SalesNumber'
	ELSE
		SET @Qry += ' ORDER BY s.SalesNumber DESC'
	
	SET @Qry += ' OFFSET @OffsetRows ROWS 
	FETCH NEXT @Pagesize ROWS ONLY '
 
	EXEC sp_executesql
		@Qry,
		N'@PayeeId INT, @SearchTrimmed NVARCHAR(50), @SearchInt INT, @SearchAmount DECIMAL(18, 2), @StartDate DATE, @EndDate DATE, @OffsetRows INT, @Pagesize INT',
		@PayeeId = @PayeeId,
		@SearchTrimmed = @SearchTrimmed,
		@SearchInt = @SearchInt,
		@SearchAmount = @SearchAmount,
		@StartDate = @StartDate,
		@EndDate = @EndDate,
		@OffsetRows = @OffsetRows,
		@Pagesize = @Pagesize
END
GO
