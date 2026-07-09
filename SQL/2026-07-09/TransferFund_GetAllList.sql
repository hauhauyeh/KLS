USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================================
-- TransferFund_GetAllList
-- 2026-07-09: add @FromAccountId and @ToAccountId filters (used
--   by the two account dropdowns on the transfer-fund list).
--   Appended as the last parameters so existing positional
--   callers are unaffected. Applied in the shared WHERE section
--   so both the count and the data query honor them.
-- =============================================================
CREATE OR ALTER PROCEDURE [dbo].[TransferFund_GetAllList]
	@Pageno int,
	@Pagesize int,
	@Search nvarchar(100),
	@StartDate date,
	@EndDate date,
	@TFId INT,
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(50),
	@IsCount bit,
	@TotalCount int OUTPUT,
	@FromAccountId nvarchar(50) = NULL,
	@ToAccountId nvarchar(50) = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX);

	IF @IsCount=1
		SET @Qry = 'SELECT @RCount = COUNT(*)'
	ELSE
		SET @Qry='SELECT
    T.TFId,
    T.TFNumber,
    T.TFDate,
    T.TFType,
    T.TransferAmount,
    T.ReferenceId,
    T.IsLocked,
    T.Notes,
    AFrom.AccountName AS FromAccount,
    ATo.AccountName   AS ToAccount'

	SET @Qry += ' FROM TransferFund AS T
	LEFT JOIN Account AS AFrom ON AFrom.AccountId = T.FromAccountId
	LEFT JOIN Account AS ATo   ON ATo.AccountId   = T.ToAccountId
	WHERE T.TFType != ''DEPOSIT'''

	IF @TFId IS NOT NULL
		SET @Qry += ' AND T.TFId = ' + CAST(@TFId AS VARCHAR)

	IF @Search is not null
	BEGIN
		IF ISNUMERIC(@Search)=1
			SET @Qry += ' AND (T.TFNumber='+@Search+' OR T.TransferAmount='+@Search+' OR ReferenceId='''+@Search+''')'
		ELSE
			SET @Qry += ' AND ReferenceId='''+@Search+''''
	END

	IF @StartDate is not null
		SET @Qry += ' AND TFDate>='''+CONVERT(VARCHAR,@StartDate)+''''

	IF @EndDate is not null
		SET @Qry += ' AND TFDate<='''+CONVERT(VARCHAR,@EndDate)+''''

	-- 2026-07-09: independent From / To account filters
	IF @FromAccountId is not null
		SET @Qry += ' AND T.FromAccountId=' + @FromAccountId

	IF @ToAccountId is not null
		SET @Qry += ' AND T.ToAccountId=' + @ToAccountId

	IF @IsCount=1
	BEGIN
		EXEC sp_executesql @Qry,N'@RCount int OUTPUT',@RCount=@TotalCount OUTPUT
		RETURN
	END

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	ELSE
		SET @Qry += ' ORDER BY T.TFDate DESC,T.TFNumber DESC'

	SET @Qry += ' OFFSET '+ CONVERT(VARCHAR(100),(@PageSize * (@Pageno - 1))) +' ROWS
	FETCH NEXT '+ CONVERT(VARCHAR(100),@Pagesize) +' ROWS ONLY '

	EXEC (@Qry)

END
GO
