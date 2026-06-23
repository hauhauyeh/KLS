SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[MarketOrder_GetAllList]
    @Pageno         INT,
    @Pagesize       INT,
    @Search         NVARCHAR(200),
    @StartDate      DATE,
    @EndDate        DATE,
    @MarketAccountId INT,
    @OrderStatus    NVARCHAR(50),
    @ImportedToErp  BIT,
    @MatchFilter    NVARCHAR(50),
    @SortField      NVARCHAR(50),
    @SortOrder      NVARCHAR(50),
    @IsCount        BIT,
    @TotalCount     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX)
    DECLARE @Where NVARCHAR(MAX) = ' WHERE 1=1 '

    -- Filters
    IF @MarketAccountId IS NOT NULL
        SET @Where += ' AND o.MarketAccountId = ' + CAST(@MarketAccountId AS VARCHAR(20))

    IF @OrderStatus IS NOT NULL
        SET @Where += ' AND o.OrderStatus = ''' + REPLACE(@OrderStatus, '''', '''''') + ''''

    IF @ImportedToErp IS NOT NULL
        SET @Where += ' AND o.ImportedToErp = ' + CAST(@ImportedToErp AS VARCHAR(1))

    IF @StartDate IS NOT NULL
        SET @Where += ' AND o.OrderDate >= ''' + CONVERT(VARCHAR(10), @StartDate, 120) + ''''

    IF @EndDate IS NOT NULL
        SET @Where += ' AND o.OrderDate < ''' + CONVERT(VARCHAR(10), DATEADD(DAY, 1, @EndDate), 120) + ''''

    IF @Search IS NOT NULL AND LTRIM(RTRIM(@Search)) <> ''
    BEGIN
        SET @Search = REPLACE(@Search, '''', '''''')
        SET @Where += '
        AND (
            o.ExternalOrderId LIKE ''%' + @Search + '%''
            OR o.ExternalOrderNo LIKE ''%' + @Search + '%''
            OR o.CustomerName LIKE ''%' + @Search + '%''
            OR o.ShipToCity LIKE ''%' + @Search + '%''
        )'
    END

    IF @MatchFilter IS NOT NULL
    BEGIN
        IF @MatchFilter = 'matched'
            SET @Where += ' AND EXISTS (SELECT 1 FROM MarketOrderItem mi WHERE mi.MarketOrderId = o.MarketOrderId AND mi.UnitPrice >= 0)
                            AND NOT EXISTS (SELECT 1 FROM MarketOrderItem mi WHERE mi.MarketOrderId = o.MarketOrderId AND mi.UnitPrice >= 0 AND mi.MatchStatus = ''unmatched'')'
        ELSE IF @MatchFilter = 'unmatched'
            SET @Where += ' AND (NOT EXISTS (SELECT 1 FROM MarketOrderItem mi WHERE mi.MarketOrderId = o.MarketOrderId AND mi.UnitPrice >= 0)
                            OR NOT EXISTS (SELECT 1 FROM MarketOrderItem mi WHERE mi.MarketOrderId = o.MarketOrderId AND mi.UnitPrice >= 0 AND mi.MatchStatus <> ''unmatched''))'
        ELSE IF @MatchFilter = 'partial'
            SET @Where += ' AND EXISTS (SELECT 1 FROM MarketOrderItem mi WHERE mi.MarketOrderId = o.MarketOrderId AND mi.UnitPrice >= 0 AND mi.MatchStatus <> ''unmatched'')
                            AND EXISTS (SELECT 1 FROM MarketOrderItem mi WHERE mi.MarketOrderId = o.MarketOrderId AND mi.UnitPrice >= 0 AND mi.MatchStatus = ''unmatched'')'
    END

    -- Count mode
    IF @IsCount = 1
    BEGIN
        SET @Qry = 'SELECT @RCount = COUNT(o.MarketOrderId) FROM MarketOrder o' + @Where
        EXEC sp_executesql @Qry, N'@RCount INT OUTPUT', @RCount = @TotalCount OUTPUT
        RETURN
    END

    -- Sort
    DECLARE @OrderBy NVARCHAR(200) = ' ORDER BY o.OrderDate DESC '
    IF @SortField IS NOT NULL
    BEGIN
        DECLARE @Dir NVARCHAR(4) = CASE WHEN @SortOrder = 'desc' THEN 'DESC' ELSE 'ASC' END
        SET @OrderBy = CASE @SortField
            WHEN 'ExternalOrderNo' THEN ' ORDER BY o.ExternalOrderNo ' + @Dir
            WHEN 'ExternalOrderId' THEN ' ORDER BY o.ExternalOrderId ' + @Dir
            WHEN 'SalesChannel'    THEN ' ORDER BY o.SalesChannel ' + @Dir
            WHEN 'OrderDate'       THEN ' ORDER BY o.OrderDate ' + @Dir
            WHEN 'CustomerName'    THEN ' ORDER BY o.CustomerName ' + @Dir
            WHEN 'OrderTotal'      THEN ' ORDER BY o.OrderTotal ' + @Dir
            WHEN 'OrderStatus'     THEN ' ORDER BY o.OrderStatus ' + @Dir
            ELSE ' ORDER BY o.OrderDate DESC '
        END
    END

    -- Paged result
    DECLARE @Offset INT = @Pagesize * (@Pageno - 1)

    SET @Qry = '
    SELECT
        o.MarketOrderId,
        o.MarketAccountId,
        o.SalesChannel,
        o.ExternalOrderId,
        o.ExternalOrderNo,
        o.OrderDate,
        o.OrderStatus,
        o.CustomerName,
        o.ShipToCity,
        o.ShipToState,
        o.CurrencyCode,
        o.OrderTotal,
        o.ImportedToErp,
        o.ErpSalesId,
        ISNULL((SELECT COUNT(*) FROM MarketOrderItem mi WHERE mi.MarketOrderId = o.MarketOrderId AND mi.UnitPrice >= 0), 0) AS TotalItems,
        ISNULL((SELECT COUNT(*) FROM MarketOrderItem mi WHERE mi.MarketOrderId = o.MarketOrderId AND mi.UnitPrice >= 0 AND mi.MatchStatus <> ''unmatched''), 0) AS MatchedItems
    FROM MarketOrder o'
    + @Where
    + @OrderBy
    + ' OFFSET ' + CAST(@Offset AS VARCHAR(20)) + ' ROWS
      FETCH NEXT ' + CAST(@Pagesize AS VARCHAR(20)) + ' ROWS ONLY'

    EXEC(@Qry)
END
