USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================================
-- Deposit_GetAllList
-- 2026-07-09: add @Uncleared filter. "Uncleared" = TransferFund
--   deposits that are not yet locked (IsLocked = 0). When
--   @Uncleared = 1, restrict the list (and the count) to those
--   rows. Appended as the last parameter so existing positional
--   callers are unaffected.
-- =============================================================
CREATE OR ALTER PROCEDURE [dbo].[Deposit_GetAllList]
	@Pageno int,
	@Pagesize int,
	@Search nvarchar(100),
	@StartDate date,
	@EndDate date,
	@ToAccountId nvarchar(50),
	@Filterby nvarchar(50),
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(50),
	@IsCount bit,
	@TotalCount int OUTPUT,
	@Uncleared bit = 0
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX);

	IF @IsCount=1
		SET @Qry='SELECT @RCount=COUNT(*)'
	ELSE
		SET @Qry='SELECT TFId,TFNumber,TFDate,TransferAmount,CashbackAmount,CCFeeAmount,
	(SELECT AccountName FROM Account AS C WHERE C.AccountId=T.ToAccountId) AS ToAccount,
	(SELECT AccountName FROM Account WHERE AccountId=T.CashbackAccountId) AS CashbackAccount,T.IsLocked'

	SET @Qry+=' FROM TransferFund AS T WHERE TFType=''DEPOSIT'''

	IF @Search is not null
	BEGIN
		IF ISNUMERIC(@Search)=1
			SET @Qry += ' AND (TFNumber='+@Search+' OR TransferAmount='+@Search+')'
	END

	IF @StartDate is not null
		SET @Qry += ' AND TFDate>='''+CONVERT(VARCHAR,@StartDate)+''''

	IF @EndDate is not null
		SET @Qry += ' AND TFDate<='''+CONVERT(VARCHAR,@EndDate)+''''

	IF @ToAccountId is not null
		SET @Qry += ' AND ToAccountId='''+@ToAccountId+''''

	IF @Filterby is not null
		SET @Qry += ' AND T.TFId IN (SELECT TFId FROM TransferFundDetail WHERE CustomerPaymentId='+@Filterby+') '

	-- 2026-07-09: uncleared = not yet locked
	IF @Uncleared = 1
		SET @Qry += ' AND T.IsLocked = 0'

	IF @IsCount=1
	BEGIN
		EXEC sp_executesql @Qry,N'@RCount int OUTPUT',@RCount=@TotalCount OUTPUT
		RETURN
	END

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	ELSE
		SET @Qry += ' ORDER BY TFDate DESC,TFNumber DESC'

	SET @Qry += ' OFFSET '+ CONVERT(VARCHAR(100),(@PageSize * (@Pageno - 1))) +' ROWS
	FETCH NEXT '+ CONVERT(VARCHAR(100),@Pagesize) +' ROWS ONLY '

	EXEC (@Qry)
END
GO
