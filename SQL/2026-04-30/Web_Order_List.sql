SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Web_Order_List]
    @Pageno INT,
    @Pagesize INT,
    @Search NVARCHAR(50),
    @StartDate DATE,
    @EndDate DATE,
    @PayeeId INT,
    @SortField NVARCHAR(50),
    @SortOrder NVARCHAR(50),
    @IsCount BIT,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);
    DECLARE @Today DATE = GETDATE();

    IF @IsCount = 1
        SET @Qry = 'SELECT @RCount = COUNT(s.SalesNumber)';
    ELSE
        SET @Qry = 'SELECT
            s.SalesId,
            s.SalesNumber,
            s.SalesDate,
            s.ShipDate,
            s.ShipRoute,
            s.ShipId,
            s.SubTotal,
            s.TaxTotal,
            s.SalesTotal,
            s.Instruction,
            s.AmountDue,
            s.CustPONumber,
            s.RouteOrder,
            s.IsLocked,
            s.IsLoadSeparate,
            -- Legacy retired field:
            -- s.LoadOrder,
            p.PayeeName,
            p.City,
            s.StageId,
            ss.StageName,
            psCalc.PaymentStatusId,
            ps.PaymentStatusName,
            s.ShippingCarrierId,
            sc.PayeeName AS ShippingCarrierName,
            t.TermName,
            p.IsCreditHold,
            p.PayeePastDue,
            p.Balance,
            p.MaxInvoiceAgingDays';

    SET @Qry += ' FROM Sales AS s
        INNER JOIN Payee AS p ON p.PayeeId = s.ShipId
        LEFT JOIN Customer c ON c.PayeeId = p.PayeeId
        LEFT JOIN SalesStage ss ON ss.StageId = s.StageId
        LEFT JOIN Payee sc ON sc.PayeeId = s.ShippingCarrierId
        LEFT JOIN Term t ON t.TermId = s.TermId
        CROSS APPLY (
            SELECT
                CASE
                    WHEN s.SalesTotal > 0 THEN
                        CASE
                            WHEN s.PaymentApplied = 0 THEN 5
                            WHEN (s.PaymentApplied + ISNULL(s.DiscountApplied, 0)) < s.SalesTotal THEN 6
                            WHEN (s.PaymentApplied + ISNULL(s.DiscountApplied, 0)) = s.SalesTotal THEN 7
                            WHEN (s.PaymentApplied + ISNULL(s.DiscountApplied, 0)) > s.SalesTotal THEN 8
                        END
                    WHEN s.SalesTotal = 0 THEN
                        CASE
                            WHEN (s.PaymentApplied + ISNULL(s.DiscountApplied, 0)) = 0 THEN 5
                            WHEN (s.PaymentApplied + ISNULL(s.DiscountApplied, 0)) > 0 THEN 8
                        END
                    WHEN s.SalesTotal < 0 THEN
                        CASE
                            WHEN s.PaymentApplied = 0 THEN 9
                            WHEN ABS(s.PaymentApplied) < ABS(s.SalesTotal) THEN 10
                            WHEN ABS(s.PaymentApplied) >= ABS(s.SalesTotal) THEN 11
                        END
                END AS PaymentStatusId
        ) AS psCalc
        LEFT JOIN PaymentStatus AS ps ON ps.PaymentStatusId = psCalc.PaymentStatusId
        WHERE p.PayeeType = ''c''';

    SET @Qry += ' AND s.ShipId = ' + CONVERT(VARCHAR, @PayeeId);

    IF @Search IS NOT NULL
        SET @Qry += ' AND (s.SalesNumber = ' + @Search + ' OR s.SalesTotal = ' + @Search + ')';

    IF @StartDate IS NOT NULL
        SET @Qry += ' AND s.ShipDate >= ''' + CONVERT(VARCHAR, @StartDate) + '''';

    IF @EndDate IS NOT NULL
        SET @Qry += ' AND s.ShipDate <= ''' + CONVERT(VARCHAR, @EndDate) + '''';

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
    ELSE IF @StartDate IS NOT NULL
        SET @Qry += ' ORDER BY s.ShipRoute, s.RouteOrder, p.PayeeName, s.SalesNumber';
    ELSE
        SET @Qry += ' ORDER BY s.SalesNumber DESC';

    SET @Qry += ' OFFSET ' + CONVERT(VARCHAR(100), (@PageSize * (@Pageno - 1))) + ' ROWS
        FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY ';

    EXEC (@Qry);
END
GO
