SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[ItemTariff_GetAllList] -- EXEC dbo.ItemTariff_GetAllList @Pageno=1, @Pagesize=50, @Search=NULL, @SortField=NULL, @SortOrder=NULL, @IsCount=0, @TotalCount=0
	@Pageno int,
	@Pagesize int,
	@Search nvarchar(50),
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(50),
	@IsCount bit,
	@TotalCount int OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX);

	IF @IsCount = 1
		SET @Qry = 'SELECT @RCount = COUNT(*)'
	ELSE
		SET @Qry = '
			SELECT 
				 it.ItemTariffId
				,it.ItemId
				,i.ItemName
				,it.CountryCode
				,c.CountryName
				,it.DutyRate
				,it.TariffRate';

	SET @Qry += ' FROM ItemTariff it
		INNER JOIN Item i ON i.ItemId = it.ItemId
		LEFT JOIN Country c ON c.ISOAlpha2 = it.CountryCode OR c.CountryCode = it.CountryCode
		WHERE 1 = 1';

	IF @Search IS NOT NULL
	BEGIN
		SET @Search = REPLACE(@Search, '''', '''''');
	
		SET @Qry += '
			AND (
				i.ItemCode = ''' + CONVERT(NVARCHAR(100), @Search) + ''' OR
				i.ItemName LIKE ''%' + CONVERT(NVARCHAR(100), @Search) + '%''
			) ';
	END

	-- Count mode
	IF @IsCount = 1
	BEGIN
		EXEC sp_executesql @Qry,N'@RCount int OUTPUT',@RCount=@TotalCount OUTPUT
		RETURN;
	END

	-- Sorting
	IF @SortField IS NOT NULL AND LTRIM(RTRIM(@SortField)) <> ''
		SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder + ' ';
	ELSE
		SET @Qry += ' ORDER BY i.ItemName ';

	-- Paging
	SET @Qry += 'OFFSET ' + CONVERT(VARCHAR(100), (@PageSize * (@Pageno - 1))) + ' ROWS
		FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY';

	EXEC (@Qry)
END
GO
