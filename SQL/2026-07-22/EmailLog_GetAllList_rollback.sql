-- EmailLog_GetAllList_rollback.sql
-- Reverts EmailLog_GetAllList.sql back to the 2026-07-22 live baseline.
-- (Restores the original signature and body, including the pre-existing search
-- behavior. Safe to run after rolling back the API to the pre-Phase-5 build.)

SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [dbo].[EmailLog_GetAllList]
	@Pageno int,
	@Pagesize int,
	@Search nvarchar(100),
	@StartDate date,
	@EndDate date,
	@Filterby nvarchar(100),
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(50),
	@IsCount bit,
	@TotalCount int OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX)

	IF @IsCount = 1
		SET @Qry = 'SELECT @RCount = COUNT(*)';
	ELSE
		SET @Qry = '
		SELECT E.EmailLogId, P.PayeeName, E.PayeeId, E.EventType, E.Email, E.SentDate, E.Status, E.ErrorMessage '

	SET  @Qry+= ' FROM EmailLog AS E LEFT JOIN Payee AS P ON E.PayeeId = P.PayeeId WHERE 1=1 '

	IF @Filterby is not null
		SET @Qry+=' AND E.EventType='''+@Filterby+''''

	IF @Search is not null
	BEGIN
		IF ISNUMERIC(@Search)=1
			SET @Qry+=' AND (p.PayeeName like ''%'+@Search+'%'' or e.Email like ''%'+@Search+'%'')'
	END

	IF @StartDate is not null
		SET @Qry += ' AND CONVERT(DATE,E.SentDate)>='''+CONVERT(VARCHAR,@StartDate)+''''

	IF @EndDate is not null
		SET @Qry += ' AND CONVERT(DATE,E.SentDate)<='''+CONVERT(VARCHAR,@EndDate)+''''

	IF @IsCount=1
	BEGIN
		EXEC sp_executesql @Qry,N'@RCount int OUTPUT',@RCount=@TotalCount OUTPUT
		RETURN
	END

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	ELSE
		SET @Qry+=' ORDER BY E.EmailLogId DESC'

	SET @Qry += ' OFFSET '+ CONVERT(VARCHAR(100),(@PageSize * (@Pageno - 1))) +' ROWS
	FETCH NEXT '+ CONVERT(VARCHAR(100),@Pagesize) +' ROWS ONLY '

	EXEC (@Qry)
END
GO

PRINT 'EmailLog_GetAllList rolled back to 2026-07-22 baseline.';
GO
