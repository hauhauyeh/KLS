SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Add sales-role customer restriction to Payee_ARList.

DROP PROCEDURE IF EXISTS [dbo].[Payee_ARList_prev];
GO

EXEC sp_rename 'Payee_ARList', 'Payee_ARList_prev';
GO

CREATE PROCEDURE [dbo].[Payee_ARList]
    @Pageno int,
    @Pagesize int,
    @Search nvarchar(100),
    @Filterby nvarchar(100),
    @EmpId INT,
    @SortField NVARCHAR(50),
    @SortOrder NVARCHAR(50),
    @IsCount bit,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Qry NVARCHAR(MAX);
    IF @IsCount=1
        SET @Qry='SELECT @RCount=COUNT(*)'
    ELSE
        SET @Qry='SELECT *'
    SET @Qry+=' FROM View_Customer WHERE 1=1'
    IF @Search IS NOT NULL
    BEGIN
        SET @Search = REPLACE(@Search,'''', '''''')
        SET @Qry+=' AND (PayeeName like N''%' + CONVERT(NVARCHAR(100),@Search) + '%'')'
    END
    If @Filterby='0'
        SET @Qry += ' '
    ELSE
    BEGIN
        IF @Search IS NULL
            SET @Qry += ' and PayeePastDue!=0'
    END
    IF @Filterby is not null
    BEGIN
        IF @Filterby = '0'
            SET @Qry += ' AND PayeeCurrent>0 '
        ELSE IF @Filterby = 'All'
            SET @Qry += ' AND PayeeTotalDue>0 '
        ELSE IF @Filterby = 'autopmt'
            SET @Qry += ' AND IsAutoPayment=1 and PayeePastDue!=0 '
        ELSE IF @Filterby = 'pastdue'
            SET @Qry += ' AND PayeePastDue>0 '
        ELSE IF @Filterby = 'credithold'
            SET @Qry += ' AND IsCreditHold=1 '
        ELSE IF @Filterby = 'cod'
            SET @Qry += ' AND TermName=''COD'' '
        ELSE IF @Filterby = 'b2b'
            SET @Qry += ' AND TermName=''B2B'' '
        ELSE IF @Filterby = 'monthly'
            SET @Qry += ' AND TermName=''Monthly'' '
        ELSE IF @Filterby = 'semimonthly'
            SET @Qry += ' AND TermName=''Semi-Monthly'' '
        ELSE IF @Filterby = 'weekly'
            SET @Qry += ' AND TermName=''Weekly'' '
        ELSE IF @Filterby = 'net30'
            SET @Qry += ' AND TermName LIKE ''NET30%'' '
        ELSE IF @Filterby = 'net15'
            SET @Qry += ' AND TermName LIKE ''NET15%'' '
        ELSE IF @Filterby = 'net14'
            SET @Qry += ' AND TermName=''NET14'' '
        ELSE IF @Filterby = 'net21'
            SET @Qry += ' AND TermName=''NET21'' '
        ELSE IF @Filterby = 'net7'
            SET @Qry += ' AND TermName LIKE ''NET7%'' '
        ELSE IF @Filterby = 'prepaid'
            SET @Qry += ' AND TermName=''PREPAID'' '
    END
    IF @EmpId > 0
        SET @Qry += ' AND SalesRepId = ' + CONVERT(VARCHAR, @EmpId)
    IF @IsCount=1
    BEGIN
        EXEC sp_executesql @Qry,N'@RCount int OUTPUT',@RCount=@TotalCount OUTPUT
        RETURN
    END
    IF @SortField is not null
        SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
    ELSE
        SET @Qry += ' ORDER BY PayeePastDue DESC,PayeeName'
    SET @Qry += ' OFFSET '+ CONVERT(VARCHAR(100),(@PageSize * (@Pageno - 1))) +' ROWS
    FETCH NEXT '+ CONVERT(VARCHAR(100),@Pagesize) +' ROWS ONLY '
    EXEC (@Qry)
END
GO
