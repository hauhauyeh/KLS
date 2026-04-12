SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[CustomerPayment_GetAllList] --[CustomerPayment_GetAllList] 1,50,null,null,null,null,100110,0
	
	@Pageno int,
	@Pagesize int,
	@Search nvarchar(50),
	@StartDate date,
	@EndDate date,
	@Filterby nvarchar(50),
	@PayeeId int,
	@EmpId INT,
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(50),
	@IsCount bit,
	@TotalCount int output
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX);
	DECLARE @IsSalesRole BIT=0

	SELECT @IsSalesRole=r.IsSalesRole 
	FROM SystemUser u inner join SystemRole r on u.SystemRoleId=r.SystemRoleId
	WHERE PayeeId=@EmpId

	IF @IsCount=1
		SET @Qry='SELECT @RCount=COUNT(*)'
	ELSE
		SET @Qry='SELECT 
		cp.CustomerPaymentId
		,cp.PaymentNumber
		,CASE WHEN cp.PaymentType=''Bad Debit'' THEN ''Bad Debt'' ELSE cp.PaymentType END AS PaymentType
		,cp.PayeeId
		,p.PayeeName
		,cp.PaymentDate
		,cp.PaymentMethod
		,cp.ReferenceId
		,cp.PaymentAmount
		,cp.PaymentApplied
		,cp.UnappliedAmount
		,cp.Notes
		,cp.IsLocked
		,cp.IsReturned'

	SET @Qry+=' FROM CustomerPayment cp INNER JOIN Payee as p ON p.PayeeId = cp.PayeeId 
	INNER JOIN Customer c ON c.PayeeId = p.PayeeId
	WHERE PaymentType NOT IN (''Vendor Refund'',''Other Incoming Payment'')'

-- ================== FILTERS ==================

	IF @IsSalesRole=1
		SET @Qry+=' AND c.SalesRepId='+CONVERT(VARCHAR,@EmpId)

	IF @StartDate is not null
		SET @Qry += ' AND cp.PaymentDate>='''+CONVERT(VARCHAR,@StartDate)+''''

	IF @EndDate is not null
		SET @Qry += ' AND cp.PaymentDate<='''+CONVERT(VARCHAR,@EndDate)+''''
	
	--If @Date is not null
	--	SET @Qry+=' AND PaymentDate='''+convert(varchar,@Date,101)+''''

	IF @PayeeId is not null
		SET @Qry += ' AND cp.PayeeId='+convert(varchar,@PayeeId)+''

	IF @Search is not null
		SET @Qry += ' AND (PaymentNumber in ('+@Search+') OR cp.ReferenceId='''+@Search+''' OR cp.PaymentAmount='''+@Search+''')'

	IF @Filterby = 'notyet'
		SET @Qry += ' AND UnappliedAmount!=0 AND IsReturned=0 AND PaymentType=''Actual Payment'''

	IF @Filterby = 'credit'
	BEGIN
		SET @Qry += ' AND UnappliedAmount!=0 AND IsReturned=0 AND PaymentType NOT IN (''Bad Debit'',''Bad Debt'',''Customer Refund'') '

		--IF @Content>0
		--	SET @Qry += ' AND CustId='+@Content+''
	END

	IF @Filterby = 'return'
		SET @Qry += ' AND IsReturned=1'

	IF @Filterby IN ('BadDebit','baddebit','BadDebt','baddebt')
		SET @Qry += ' AND PaymentType IN (''Bad Debit'',''Bad Debt'')'

	IF @Filterby = 'CreditApply'
		SET @Qry += ' AND PaymentType=''Credit Apply'''

	IF @Filterby = 'refund'
		SET @Qry += ' AND PaymentType=''Customer Refund'''

	IF @IsCount=1
	BEGIN		
		EXEC sp_executesql @Qry,N'@RCount int OUTPUT',@RCount=@TotalCount OUTPUT
		RETURN
	END

-- ================== SORTING ==================

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	ELSE
	BEGIN
		IF @Filterby='notyet'
			SET @Qry += ' ORDER BY PaymentDate DESC,PaymentMethod,PaymentNumber DESC'
		--ELSE IF @Date IS NOT NULL
		--	SET @Qry += ' ORDER BY PaymentMethod,PayeeName,PaymentNumber'
		ELSE IF @Search IS NOT NULL
			SET @Qry += ' ORDER BY PaymentDate,PaymentMethod,ReferenceId,PaymentNumber'
		ELSE
			SET @Qry += ' ORDER BY PaymentDate DESC,PaymentNumber DESC'
	END

-- ================== PAGINATION ==================
	
	SET @Qry += ' OFFSET '+ CONVERT(VARCHAR(100),(@PageSize * (@Pageno - 1))) +' ROWS 
	FETCH NEXT '+ CONVERT(VARCHAR(100),@Pagesize) +' ROWS ONLY '

	EXEC (@Qry)
END
GO
