
-- 2026-07-22 BACKORDER-DROPSHIP-DUPLICATE-GUARD: expose whether a drop-ship SO already has a backorder child.
CREATE   PROCEDURE [dbo].[Sales_GetAllList] -- EXEC [Sales_GetAllList] 1,50,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,0,NULL
(
    @Pageno INT,
    @Pagesize INT,
    @Search NVARCHAR(50),
    @StartDate DATE,
    @EndDate DATE,
    @PayeeId INT,
    @ShipRoute NVARCHAR(50),
    @Id INT,
    @Filterby NVARCHAR(50),
    @EmpId INT,
    @SortField NVARCHAR(50),
    @SortOrder NVARCHAR(50),
    @IsCount BIT,
    @TotalCount INT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);
    DECLARE @Today DATE = GETDATE();
    DECLARE @IsSalesRole BIT = 0;

    -- Get Sales Role
    SELECT @IsSalesRole = r.IsSalesRole
    FROM SystemUser u
    INNER JOIN SystemRole r ON u.SystemRoleId = r.SystemRoleId
    WHERE PayeeId = @EmpId;

    -- Count vs Data Query
    IF @IsCount = 1
        SET @Qry = 'SELECT @RCount = COUNT(s.SalesNumber)';
    ELSE
        SET @Qry = '
        SELECT
            s.SalesId,
            s.SalesNumber,
            s.DocType,
            s.ParentSalesNumber,
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
            s.TruckNumber,
            de.PayeeName AS DriverName,
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
            p.MaxInvoiceAgingDays,
            CAST(CASE 
                WHEN s.AmountDue <> 0 
                     AND s.DueDate < ''' + CONVERT(VARCHAR(10), @Today, 120) + '''
                THEN 1 
                ELSE 0 
            END AS bit) AS IsPastDue,
            s.IsDropShip,
            s.DropShipPurchaseId,
            dsp.PurchaseNumber AS DropShipPurchaseNumber,
            dsp.StageId AS DropShipPurchaseStageId,
            dsp.PayeeId AS DropShipPurchasePayeeId,
            dsp.FactorPO AS DropShipPurchaseFactorPO,
            CAST(CASE WHEN EXISTS
            (
                SELECT 1
                FROM dbo.Sales child
                WHERE child.ParentSalesNumber = s.SalesNumber
                  AND child.IsDropShip = 1
                  AND child.DocType = ''SO''
            ) THEN 1 ELSE 0 END AS bit) AS HasBackorderDropShip';

    -- Base Query
    SET @Qry += '
        FROM Sales AS s
        INNER JOIN Payee AS p ON p.PayeeId = s.ShipId
        LEFT JOIN Customer c ON c.PayeeId = p.PayeeId
        LEFT JOIN SalesStage ss ON ss.StageId = s.StageId
        LEFT JOIN Payee sc ON sc.PayeeId = s.ShippingCarrierId
        LEFT JOIN Term t ON t.TermId = s.TermId
        LEFT JOIN Payee de ON de.PayeeId = s.Deliverby
        LEFT JOIN Purchase AS dsp ON dsp.PurchaseId = s.DropShipPurchaseId

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
                    WHEN s.DocType = ''CM'' OR (s.DocType = ''SO'' AND s.SalesTotal < 0) THEN
                        CASE
                            WHEN s.PaymentApplied = 0 THEN 9
                            WHEN ABS(s.PaymentApplied) < ABS(s.SalesTotal) THEN 10
                            WHEN ABS(s.PaymentApplied) >= ABS(s.SalesTotal) THEN 11
                        END
                END AS PaymentStatusId
        ) AS psCalc
        LEFT JOIN PaymentStatus ps ON ps.PaymentStatusId = psCalc.PaymentStatusId

        WHERE p.PayeeType = ''c''';

    -- Filters
    IF @IsSalesRole = 1
        SET @Qry += ' AND c.SalesRepId = ' + CONVERT(VARCHAR, @EmpId);

    IF @Id IS NOT NULL
        SET @Qry += ' AND s.SalesId = ' + CONVERT(VARCHAR, @Id);

    IF @Search IS NOT NULL
        SET @Qry += ' AND (s.SalesNumber = ' + @Search + ' OR s.SalesTotal = ' + @Search + ')';

    IF @PayeeId IS NOT NULL
        SET @Qry += ' AND s.ShipId = ' + CONVERT(VARCHAR, @PayeeId);

    IF @StartDate IS NOT NULL
        SET @Qry += ' AND s.ShipDate >= ''' + CONVERT(VARCHAR, @StartDate) + '''';

    IF @EndDate IS NOT NULL
        SET @Qry += ' AND s.ShipDate <= ''' + CONVERT(VARCHAR, @EndDate) + '''';

    IF @ShipRoute IS NOT NULL
    BEGIN
        IF @ShipRoute = 'blank'
            SET @Qry += ' AND s.ShipRoute IS NULL';
        ELSE
            SET @Qry += ' AND ISNULL(s.ShipRoute, '''') = ''' + @ShipRoute + '''';
    END

    IF @Filterby IS NOT NULL
    BEGIN
        IF @Filterby = 'web'
            SET @Qry += ' AND s.Instruction LIKE ''%web%''';
        ELSE IF @Filterby = 'order'
            SET @Qry += ' AND s.StageId = 0';
        ELSE IF @Filterby = 'loading'
            SET @Qry += ' AND s.StageId = 2';
        ELSE IF @Filterby = 'transit'
            SET @Qry += ' AND s.StageId = 3';
        ELSE IF @Filterby = 'cmorder'
            SET @Qry += ' AND s.StageId = 0 AND (s.DocType = ''CM'' OR (s.DocType = ''SO'' AND s.SalesTotal < 0))';
        ELSE IF @Filterby = 'cmsuccess'
            SET @Qry += ' AND s.StageId = 4 AND (s.DocType = ''CM'' OR (s.DocType = ''SO'' AND s.SalesTotal < 0))';
        ELSE IF @Filterby = 'dmorder'
            SET @Qry += ' AND s.StageId = 0 AND s.DocType = ''DM''';
        ELSE IF @Filterby = 'dmsuccess'
            SET @Qry += ' AND s.StageId = 4 AND s.DocType = ''DM''';
        ELSE IF @Filterby = 'pastdue'
            SET @Qry += ' AND s.AmountDue <> 0 AND s.DueDate < ''' + CONVERT(VARCHAR, @Today) + '''';
        ELSE IF @Filterby = 'unpaid'
            SET @Qry += ' AND s.AmountDue <> 0';
    END

    -- Count Execution
    IF @IsCount = 1
    BEGIN
        EXEC sp_executesql
            @Qry,
            N'@RCount INT OUTPUT',
            @RCount = @TotalCount OUTPUT;
        RETURN;
    END

    -- Sorting
    IF @SortField IS NOT NULL
        SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder;
    ELSE IF @StartDate IS NOT NULL
        SET @Qry += ' ORDER BY s.ShipRoute, s.RouteOrder, p.PayeeName, s.SalesNumber';
    ELSE
        SET @Qry += ' ORDER BY s.SalesNumber DESC';

    -- Pagination
    SET @Qry += '
        OFFSET ' + CONVERT(VARCHAR(100), (@PageSize * (@Pageno - 1))) + ' ROWS
        FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY';

    -- PRINT @Qry;

    EXEC (@Qry);
END




