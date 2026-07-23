
CREATE PROCEDURE [dbo].[EmailLog_GetAllList]
	@Pageno int,
	@Pagesize int,
	@Search nvarchar(100),
	@StartDate date,
	@EndDate date,
	@Filterby nvarchar(100),
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(50),
	@IsCount bit,
	@TotalCount int OUTPUT,
	@Category nvarchar(50) = NULL,
	@EmailType nvarchar(50) = NULL,
	@DeliveryStatus nvarchar(30) = NULL
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX);

	-- Shared WHERE clause (fully parameterized).
	DECLARE @Where NVARCHAR(MAX) =
		N' FROM EmailLog AS E LEFT JOIN Payee AS P ON E.PayeeId = P.PayeeId WHERE 1=1 ';

	IF @Filterby IS NOT NULL
		SET @Where += N' AND E.EventType = @Filterby ';

	IF @Category IS NOT NULL
		SET @Where += N' AND E.EmailCategory = @Category ';

	IF @EmailType IS NOT NULL
		SET @Where += N' AND E.EmailType = @EmailType ';

	IF @DeliveryStatus IS NOT NULL
		SET @Where += N' AND E.DeliveryStatus = @DeliveryStatus ';

	IF @Search IS NOT NULL
		SET @Where += N' AND (P.PayeeName LIKE ''%'' + @Search + ''%''
		                   OR E.Email LIKE ''%'' + @Search + ''%''
		                   OR E.DocumentNumber LIKE ''%'' + @Search + ''%''
		                   OR E.Subject LIKE ''%'' + @Search + ''%''
		                   OR E.EmailType LIKE ''%'' + @Search + ''%''
		                   OR E.EventType LIKE ''%'' + @Search + ''%'') ';

	IF @StartDate IS NOT NULL
		SET @Where += N' AND CONVERT(DATE, E.SentDate) >= @StartDate ';

	IF @EndDate IS NOT NULL
		SET @Where += N' AND CONVERT(DATE, E.SentDate) <= @EndDate ';

	DECLARE @ParamDef NVARCHAR(MAX) =
		N'@Search nvarchar(100), @Filterby nvarchar(100), @Category nvarchar(50),
		  @EmailType nvarchar(50), @DeliveryStatus nvarchar(30), @StartDate date, @EndDate date';

	IF @IsCount = 1
	BEGIN
		SET @Qry = N'SELECT @RCount = COUNT(*) ' + @Where;
		EXEC sp_executesql @Qry,
			N'@RCount int OUTPUT, @Search nvarchar(100), @Filterby nvarchar(100), @Category nvarchar(50),
			  @EmailType nvarchar(50), @DeliveryStatus nvarchar(30), @StartDate date, @EndDate date',
			@RCount = @TotalCount OUTPUT,
			@Search = @Search, @Filterby = @Filterby, @Category = @Category,
			@EmailType = @EmailType, @DeliveryStatus = @DeliveryStatus,
			@StartDate = @StartDate, @EndDate = @EndDate;
		RETURN;
	END

	-- Whitelist sort column; fall back to EmailLogId DESC.
	DECLARE @OrderCol NVARCHAR(100) =
		CASE @SortField
			WHEN 'PayeeName'      THEN 'P.PayeeName'
			WHEN 'SentDate'       THEN 'E.SentDate'
			WHEN 'EventType'      THEN 'E.EventType'
			WHEN 'EmailType'      THEN 'E.EmailType'
			WHEN 'EmailCategory'  THEN 'E.EmailCategory'
			WHEN 'Email'          THEN 'E.Email'
			WHEN 'DeliveryStatus' THEN 'E.DeliveryStatus'
			WHEN 'DocumentNumber' THEN 'E.DocumentNumber'
			WHEN 'Status'         THEN 'E.Status'
			ELSE NULL
		END;

	DECLARE @Dir NVARCHAR(4) = CASE WHEN @SortOrder = 'asc' THEN 'ASC' ELSE 'DESC' END;
	DECLARE @OrderBy NVARCHAR(150) =
		CASE WHEN @OrderCol IS NULL THEN 'E.EmailLogId DESC' ELSE @OrderCol + ' ' + @Dir END;

	SET @Qry =
		N'SELECT E.EmailLogId, P.PayeeName, E.PayeeId, E.EventType, E.Email, E.SentDate, E.Status, E.ErrorMessage,
		         E.EmailCategory, E.EmailType, E.FromEmail, E.DocumentType, E.DocumentId, E.DocumentNumber,
		         E.RelatedEntityType, E.RelatedEntityId, E.Subject, E.RequestedBy, E.Source, E.Provider, E.DeliveryStatus '
		+ @Where
		+ N' ORDER BY ' + @OrderBy
		+ N' OFFSET ' + CONVERT(VARCHAR(20), (@Pagesize * (@Pageno - 1))) + N' ROWS'
		+ N' FETCH NEXT ' + CONVERT(VARCHAR(20), @Pagesize) + N' ROWS ONLY ';

	EXEC sp_executesql @Qry, @ParamDef,
		@Search = @Search, @Filterby = @Filterby, @Category = @Category,
		@EmailType = @EmailType, @DeliveryStatus = @DeliveryStatus,
		@StartDate = @StartDate, @EndDate = @EndDate;
END
