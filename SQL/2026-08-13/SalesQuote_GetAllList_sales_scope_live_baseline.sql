
-- SalesQuote Module - Stored Procedures
-- 8 SPs: GetAllList, Insert, Update, Inject, Delete, UpdateStatus, ConvertToSales
-- Temp SPs: GetList, Clear, AddLine

-- ============================================
-- SalesQuote_GetAllList
-- 2026-08-11: return SalesQuoteType for Sales Quote type CRUD.
-- ============================================
CREATE   PROCEDURE [dbo].[SalesQuote_GetAllList]
    @Pageno         INT,
    @Pagesize       INT,
    @Search         NVARCHAR(100),
    @StartDate      DATE,
    @EndDate        DATE,
    @Filterby       NVARCHAR(50),
    @PayeeId        INT,
    @EmpId          INT,
    @SortField      NVARCHAR(50),
    @SortOrder      NVARCHAR(50),
    @IsCount        BIT,
    @TotalCount     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);

    IF @IsCount = 1
        SET @Qry = 'SELECT @RCount = COUNT(*)';
    ELSE
        SET @Qry = '
        SELECT
            sq.SalesQuoteId,
            sq.QuoteNumber,
            sq.SalesQuoteType,
            sq.QuoteDate,
            sq.ExpiryDate,
            sq.PayeeId,
            p.PayeeName,
            sq.SalesRepId,
            e.PayeeName AS SalesRepName,
            sq.SubTotal,
            sq.TaxTotal,
            sq.QuoteTotal,
            sq.StatusId,
            CASE sq.StatusId
                WHEN 0 THEN ''Draft''
                WHEN 1 THEN ''Sent''
                WHEN 2 THEN ''Accepted''
                WHEN 3 THEN ''Rejected''
                WHEN 4 THEN ''Expired''
                WHEN 5 THEN ''Converted''
            END AS StatusName,
            sq.Notes,
            sq.SalesId,
            sq.Enterby,
            sq.CreatedAt,
            sq.UpdatedAt,
            (
                SELECT COUNT(*)
                FROM SalesQuoteDetail
                WHERE SalesQuoteId = sq.SalesQuoteId
            ) AS LineCount';

    SET @Qry += '
        FROM SalesQuote sq
        LEFT JOIN Payee p ON p.PayeeId = sq.PayeeId
        LEFT JOIN Payee e ON e.PayeeId = sq.SalesRepId
        WHERE 1 = 1';

    IF @Search IS NOT NULL
    BEGIN
        SET @Search = REPLACE(@Search, '''', '''''');
        SET @Qry += ' AND (
            sq.QuoteNumber = TRY_CAST(''' + @Search + ''' AS INT)
            OR sq.QuoteTotal = TRY_CAST(''' + @Search + ''' AS DECIMAL(18,2)) 
        )';
    END

    IF @StartDate IS NOT NULL
        SET @Qry += ' AND sq.QuoteDate >= ''' + CONVERT(VARCHAR, @StartDate) + '''';

    IF @EndDate IS NOT NULL
        SET @Qry += ' AND sq.QuoteDate < DATEADD(DAY, 1, ''' + CONVERT(VARCHAR, @EndDate) + ''')';

    IF @Filterby IS NOT NULL
        SET @Qry += ' AND sq.StatusId = TRY_CAST(''' + REPLACE(@Filterby, '''', '''''') + ''' AS INT)';

    IF @PayeeId IS NOT NULL
        SET @Qry += ' AND sq.PayeeId = ' + CONVERT(VARCHAR, @PayeeId);

    IF @IsCount = 1
    BEGIN
        EXEC sp_executesql
            @Qry,
            N'@RCount INT OUTPUT',
            @RCount = @TotalCount OUTPUT;
        RETURN;
    END

    IF @SortField IS NOT NULL
        SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder;
    ELSE
        SET @Qry += ' ORDER BY sq.SalesQuoteId DESC';

    SET @Qry += '
        OFFSET ' + CONVERT(VARCHAR(100), (@PageSize * (@Pageno - 1))) + ' ROWS
        FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY';

    EXEC (@Qry);
END
