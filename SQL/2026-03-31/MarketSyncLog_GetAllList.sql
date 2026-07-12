SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[MarketSyncLog_GetAllList]
    @Pageno          INT,
    @Pagesize        INT,
    @Search          NVARCHAR(200),
    @StartDate       DATE,
    @EndDate         DATE,
    @MarketAccountId INT,
    @SyncType        NVARCHAR(50),
    @Success         BIT,
    @SortField       NVARCHAR(50),
    @SortOrder       NVARCHAR(50),
    @IsCount         BIT,
    @TotalCount      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX)
    DECLARE @Where NVARCHAR(MAX) = ' WHERE 1=1 '

    IF @MarketAccountId IS NOT NULL
        SET @Where += ' AND l.MarketAccountId = ' + CAST(@MarketAccountId AS VARCHAR(20))

    IF @SyncType IS NOT NULL
        SET @Where += ' AND l.SyncType = ''' + REPLACE(@SyncType, '''', '''''') + ''''

    IF @Success IS NOT NULL
        SET @Where += ' AND l.Success = ' + CAST(@Success AS VARCHAR(1))

    IF @StartDate IS NOT NULL
        SET @Where += ' AND l.StartedAt >= ''' + CONVERT(VARCHAR(10), @StartDate, 120) + ''''

    IF @EndDate IS NOT NULL
        SET @Where += ' AND l.StartedAt < ''' + CONVERT(VARCHAR(10), DATEADD(DAY, 1, @EndDate), 120) + ''''

    IF @Search IS NOT NULL AND LTRIM(RTRIM(@Search)) <> ''
    BEGIN
        SET @Search = REPLACE(@Search, '''', '''''')
        SET @Where += '
        AND (
            l.SyncType LIKE ''%' + @Search + '%''
            OR l.ErrorMessage LIKE ''%' + @Search + '%''
            OR l.ReferenceNo LIKE ''%' + @Search + '%''
            OR a.AccountName LIKE ''%' + @Search + '%''
        )'
    END

    -- Count mode
    IF @IsCount = 1
    BEGIN
        SET @Qry = 'SELECT @RCount = COUNT(l.MarketSyncLogId) FROM MarketSyncLog l INNER JOIN MarketAccount a ON l.MarketAccountId = a.MarketAccountId' + @Where
        EXEC sp_executesql @Qry, N'@RCount INT OUTPUT', @RCount = @TotalCount OUTPUT
        RETURN
    END

    -- Sort
    DECLARE @OrderBy NVARCHAR(200) = ' ORDER BY l.StartedAt DESC '
    IF @SortField IS NOT NULL
    BEGIN
        DECLARE @Dir NVARCHAR(4) = CASE WHEN @SortOrder = 'desc' THEN 'DESC' ELSE 'ASC' END
        SET @OrderBy = CASE @SortField
            WHEN 'SyncType'         THEN ' ORDER BY l.SyncType ' + @Dir
            WHEN 'StartedAt'        THEN ' ORDER BY l.StartedAt ' + @Dir
            WHEN 'FinishedAt'       THEN ' ORDER BY l.FinishedAt ' + @Dir
            WHEN 'Success'          THEN ' ORDER BY l.Success ' + @Dir
            WHEN 'RecordsProcessed' THEN ' ORDER BY l.RecordsProcessed ' + @Dir
            WHEN 'AccountName'      THEN ' ORDER BY a.AccountName ' + @Dir
            ELSE ' ORDER BY l.StartedAt DESC '
        END
    END

    -- Paged result
    DECLARE @Offset INT = @Pagesize * (@Pageno - 1)

    SET @Qry = '
    SELECT
        l.MarketSyncLogId,
        l.MarketAccountId,
        a.AccountName,
        l.SyncType,
        l.StartedAt,
        l.FinishedAt,
        l.Success,
        l.RecordsProcessed,
        l.RecordsSucceeded,
        l.RecordsFailed,
        l.ReferenceNo,
        l.ErrorMessage
    FROM MarketSyncLog l
    INNER JOIN MarketAccount a ON l.MarketAccountId = a.MarketAccountId'
    + @Where
    + @OrderBy
    + ' OFFSET ' + CAST(@Offset AS VARCHAR(20)) + ' ROWS
      FETCH NEXT ' + CAST(@Pagesize AS VARCHAR(20)) + ' ROWS ONLY'

    EXEC(@Qry)
END
GO
