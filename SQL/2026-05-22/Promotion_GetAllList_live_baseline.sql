/*
    Promotion_GetAllList_live_baseline.sql
    Captured 2026-05-22

    Frozen snapshot of the currently-deployed Promotion_GetAllList as of the
    start of this round. Reference for rollback if needed.

    DO NOT EDIT — baseline only.
*/

CREATE PROCEDURE [dbo].[Promotion_GetAllList] --[dbo].[Promotion_GetAllList] Null,Null,Null,Null,Null,Null,Null,Null,0,0
    @Pageno INT,
    @Pagesize INT,
    @Search NVARCHAR(100),
    @StartDate DATE,
    @EndDate DATE,
    @Filterby NVARCHAR(100),
    @SortField NVARCHAR(50),
    @SortOrder NVARCHAR(50),
    @IsCount BIT,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);

    IF @IsCount = 1
        SET @Qry = 'SELECT @RCount = COUNT(*)';
    ELSE
        SET @Qry = '
        SELECT P.PromotionId, P.Name, P.DisplayName, P.PromotionType,
               P.StartDate, P.EndDate, P.IsActive ';

    SET @Qry += ' FROM Promotion AS P WHERE 1=1 ';

    IF @Filterby IS NOT NULL
        SET @Qry += ' AND P.PromotionType=''' + @Filterby + '''';

    IF @Search IS NOT NULL
        SET @Qry += ' AND (P.Name like ''%' + @Search + '%''
                        OR P.DisplayName like ''%' + @Search + '%''
                        OR P.PromotionType like ''%' + @Search + '%'')';

    IF @StartDate IS NOT NULL
        SET @Qry += N' AND (P.EndDate IS NULL OR P.EndDate >= '''+CONVERT(VARCHAR,@StartDate)+''') ';

    IF @EndDate IS NOT NULL
        SET @Qry += N' AND (P.StartDate IS NULL OR P.StartDate <= '''+CONVERT(VARCHAR,@EndDate)+''') ';

    -- Count mode
    IF @IsCount = 1
    BEGIN
        EXEC sp_executesql @Qry, N'@RCount int OUTPUT', @RCount=@TotalCount OUTPUT;
        RETURN;
    END

    -- Sorting (your style)
    IF @SortField IS NOT NULL
        SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder + '';
    ELSE
        SET @Qry += ' ORDER BY P.PromotionId DESC';

    -- Paging
    SET @Qry += ' OFFSET ' + CONVERT(VARCHAR(100), (@PageSize * (@Pageno - 1))) + ' ROWS
                 FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY ';

    EXEC (@Qry);
END
