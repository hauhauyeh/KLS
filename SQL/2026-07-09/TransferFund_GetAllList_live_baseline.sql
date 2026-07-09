-- ============================================================
-- LIVE BASELINE (pre-2026-07-09) of dbo.TransferFund_GetAllList
-- The definition as it was BEFORE the From/To account filters were added.
-- Rollback: run this file to restore the prior definition.
-- ============================================================
USE [KLS-2026]
GO

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
	@TotalCount int OUTPUT
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
