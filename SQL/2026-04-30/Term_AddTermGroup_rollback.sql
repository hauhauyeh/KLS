SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[View_Customer] AS
SELECT
    p.PayeeId,
    p.PayeeName,
    c.SalesRepId,
    c.Region,
    c.DefaultRoute,
    t.TermName,
    c.IsAutoPayment,
    (
        SELECT COUNT(*)
        FROM PaymentMethod pm
        WHERE pm.PayeeId = p.PayeeId
    ) AS PaymentMethodCount,
    (
        SELECT ISNULL(PayeeName, '')
        FROM Payee
        WHERE PayeeId = c.SalesRepId
    ) AS SalesRepName,

    ISNULL(DA.DueAgeCurrent, 0) AS PayeeCurrent,
    ISNULL(DA.DueAge5, 0) AS Payee5,
    ISNULL(DA.DueAge30, 0) AS Payee30,
    ISNULL(p.Payee60, 0) AS Payee60,
    ISNULL(p.Payee90, 0) AS Payee90,
    ISNULL(p.PayeeOver90, 0) AS PayeeOver90,
    ISNULL(DA.MaxDueAgingDays, 0) AS MaxDueAgingDays,

    ISNULL(IA.InvoiceAgeCurrent, 0) AS InvoiceAgeCurrent,
    ISNULL(IA.InvoiceAge5, 0) AS InvoiceAge5,
    ISNULL(IA.InvoiceAge30, 0) AS InvoiceAge30,
    ISNULL(p.Invoice60, 0) AS InvoiceAge60,
    ISNULL(p.Invoice90, 0) AS InvoiceAge90,
    ISNULL(p.PayeeOver90, 0) AS InvoiceAgeOver90,
    ISNULL(IA.MaxInvAgingDays, 0) AS DueInvoiceDays,

    p.PayeeTotalDue,
    p.PayeePastDue,
    p.Balance,
    p.GracePeriod,
    p.LastPaymentDate,
    CASE
        WHEN p.LastPaymentDate IS NULL THEN NULL
        ELSE DATEDIFF(DAY, p.LastPaymentDate, GETDATE())
    END AS LastPaidDaysAgo,
    p.LastPaymentAmount,
    p.LastOrderDate,
    CASE
        WHEN p.LastOrderDate IS NULL THEN NULL
        ELSE DATEDIFF(DAY, p.LastOrderDate, GETDATE())
    END AS LastOrderDaysAgo,
    p.LastOrderAmount,
    p.FirstDueDate,
    p.AvgPaymentDays,
    p.IsCreditHold
FROM Payee AS p
INNER JOIN Customer AS c
    ON p.PayeeId = c.PayeeId
LEFT JOIN Term AS t
    ON t.TermId = p.TermId
OUTER APPLY
(
    SELECT
        SUM(CASE WHEN s.Aging = 0 THEN s.AmountDue ELSE 0 END) AS DueAgeCurrent,
        SUM(CASE WHEN s.Aging BETWEEN 1 AND 5 THEN s.AmountDue ELSE 0 END) AS DueAge5,
        SUM(CASE WHEN s.Aging BETWEEN 6 AND 30 THEN s.AmountDue ELSE 0 END) AS DueAge30,
        MAX(s.Aging) AS MaxDueAgingDays
    FROM dbo.Sales s
    WHERE s.ShipId = p.PayeeId
      AND s.AmountDue <> 0
) AS DA
OUTER APPLY
(
    SELECT
        SUM(CASE WHEN s.InvoiceAging = 0 THEN s.AmountDue ELSE 0 END) AS InvoiceAgeCurrent,
        SUM(CASE WHEN s.InvoiceAging BETWEEN 1 AND 5 THEN s.AmountDue ELSE 0 END) AS InvoiceAge5,
        SUM(CASE WHEN s.InvoiceAging BETWEEN 6 AND 30 THEN s.AmountDue ELSE 0 END) AS InvoiceAge30,
        MAX(s.InvoiceAging) AS MaxInvAgingDays
    FROM dbo.Sales s
    WHERE s.ShipId = p.PayeeId
      AND s.AmountDue <> 0
) AS IA;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Payee_ARList]
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

IF COL_LENGTH('dbo.Term', 'TermGroup') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Term
    DROP COLUMN TermGroup;
END
GO
