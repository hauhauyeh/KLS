SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-08-12 Order Manager expanded search: SalesDocNumber, CPO, FPO, VDOC, CONT.
-- 2026-08-08 DropShip backorder badge: expose remaining-qty and latest-chain flags.
-- Baseline: KLS/SQL/2026-08-08/Sales_GetAllList_GUS_2026_live_baseline.sql
-- 2026-08-07 DropShip refs Slice 2: expose linked purchase refs and chain sequence label.
-- 2026-07-27 SalesDocNumber Slice 6: expose SalesDocNumber for backend read model.
-- Baseline: KLS/SQL/2026-07-27/Sales_GetAllList_live_baseline.sql
CREATE OR ALTER PROCEDURE [dbo].[Sales_GetAllList] -- EXEC [Sales_GetAllList] 1,50,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,0,NULL
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
    DECLARE @S NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@Search)), N'');
    DECLARE @SearchInt INT = TRY_CONVERT(INT, @S);
    DECLARE @SearchMoney DECIMAL(18,2) = TRY_CONVERT(DECIMAL(18,2), @S);

    SELECT @IsSalesRole = r.IsSalesRole
    FROM SystemUser u
    INNER JOIN SystemRole r ON u.SystemRoleId = r.SystemRoleId
    WHERE PayeeId = @EmpId;

    IF @IsCount = 1
        SET @Qry = 'SELECT @RCount = COUNT(s.SalesNumber)';
    ELSE
        SET @Qry = '
        SELECT
            s.SalesId,
            s.SalesNumber,
            s.SalesDocNumber,
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
            dsp.VendorDocNumber AS DropShipPurchaseVendorDocNumber,
            dsp.ContainerNumber AS DropShipPurchaseContainerNumber,
            -- Calculate root/child drop-ship sequence on demand; the root order is always first.
            CASE
                WHEN s.IsDropShip = 1 THEN
                (
                    SELECT CONCAT(chainSeq.ChainOrdinal,
                        CASE
                            WHEN chainSeq.ChainOrdinal % 100 BETWEEN 11 AND 13 THEN ''th''
                            WHEN chainSeq.ChainOrdinal % 10 = 1 THEN ''st''
                            WHEN chainSeq.ChainOrdinal % 10 = 2 THEN ''nd''
                            WHEN chainSeq.ChainOrdinal % 10 = 3 THEN ''rd''
                            ELSE ''th''
                        END)
                    FROM
                    (
                        SELECT
                            chainRow.SalesNumber,
                            ROW_NUMBER() OVER
                            (
                                ORDER BY
                                    CASE WHEN chainRow.SalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber) THEN 0 ELSE 1 END,
                                    chainRow.CreatedAt,
                                    chainRow.SalesNumber
                            ) AS ChainOrdinal
                        FROM dbo.Sales AS chainRow
                        WHERE chainRow.SalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber)
                           OR chainRow.ParentSalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber)
                    ) AS chainSeq
                    WHERE chainSeq.SalesNumber = s.SalesNumber
                )
                ELSE NULL
            END AS DropShipChainLabel,
            CAST(CASE WHEN EXISTS
            (
                SELECT 1
                FROM dbo.Sales child
                WHERE child.ParentSalesNumber = s.SalesNumber
                  AND child.IsDropShip = 1
                  AND child.DocType = ''SO''
            ) THEN 1 ELSE 0 END AS bit) AS HasBackorderDropShip,
            -- Backorder DS visibility is based on remaining sales qty, not the linked PO stage.
            CAST(CASE WHEN s.IsDropShip = 1 AND EXISTS
            (
                SELECT 1
                FROM dbo.SalesDetail sd
                WHERE sd.SalesId = s.SalesId
                  AND sd.LineType = ''I''
                  AND sd.ItemId IS NOT NULL
                  AND ISNULL(sd.IsSystemManaged, 0) = 0
                  AND sd.ParentSalesDetailId IS NULL
                  AND sd.RootSalesDetailId IS NULL
                  AND ISNULL(sd.CartLineType, ''MAIN'') = ''MAIN''
                  AND ISNULL(sd.OrdQty, 0) - ISNULL(sd.ShipQty, 0) > 0
            ) THEN 1 ELSE 0 END AS bit) AS HasDSBackorderQty,
            -- Only the latest active row in a root/child drop-ship chain owns the next backorder action.
            CAST(CASE WHEN s.IsDropShip = 1 AND NOT EXISTS
            (
                SELECT 1
                FROM dbo.Sales chainLater
                WHERE (chainLater.SalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber)
                    OR chainLater.ParentSalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber))
                  AND chainLater.SalesNumber <> s.SalesNumber
                  AND
                  (
                      CASE WHEN chainLater.SalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber) THEN 0 ELSE 1 END
                        > CASE WHEN s.SalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber) THEN 0 ELSE 1 END
                      OR
                      (
                          CASE WHEN chainLater.SalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber) THEN 0 ELSE 1 END
                            = CASE WHEN s.SalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber) THEN 0 ELSE 1 END
                          AND ISNULL(chainLater.CreatedAt, ''19000101'') > ISNULL(s.CreatedAt, ''19000101'')
                      )
                      OR
                      (
                          CASE WHEN chainLater.SalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber) THEN 0 ELSE 1 END
                            = CASE WHEN s.SalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber) THEN 0 ELSE 1 END
                          AND ISNULL(chainLater.CreatedAt, ''19000101'') = ISNULL(s.CreatedAt, ''19000101'')
                          AND chainLater.SalesNumber > s.SalesNumber
                      )
                  )
            ) THEN 1 ELSE 0 END AS bit) AS IsLatestDSChain';

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

    IF @IsSalesRole = 1
        SET @Qry += ' AND c.SalesRepId = ' + CONVERT(VARCHAR, @EmpId);

    IF @Id IS NOT NULL
        SET @Qry += ' AND s.SalesId = ' + CONVERT(VARCHAR, @Id);

    IF @S IS NOT NULL
        SET @Qry += ' AND (
            s.SalesDocNumber LIKE ''%'' + @S + ''%''
            OR s.CustPONumber LIKE ''%'' + @S + ''%''
            OR dsp.FactorPO LIKE ''%'' + @S + ''%''
            OR dsp.VendorDocNumber LIKE ''%'' + @S + ''%''
            OR dsp.ContainerNumber LIKE ''%'' + @S + ''%''
            OR (@SearchInt IS NOT NULL AND s.SalesNumber = @SearchInt)
            OR (@SearchInt IS NOT NULL AND s.ParentSalesNumber = @SearchInt)
            OR (@SearchInt IS NOT NULL AND dsp.PurchaseNumber = @SearchInt)
            OR (@SearchMoney IS NOT NULL AND s.SalesTotal = @SearchMoney)
        )';

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

    IF @IsCount = 1
    BEGIN
        EXEC sp_executesql
            @Qry,
            N'@S NVARCHAR(50), @SearchInt INT, @SearchMoney DECIMAL(18,2), @RCount INT OUTPUT',
            @S = @S,
            @SearchInt = @SearchInt,
            @SearchMoney = @SearchMoney,
            @RCount = @TotalCount OUTPUT;
        RETURN;
    END

    IF @SortField IS NOT NULL
        SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder;
    ELSE IF @StartDate IS NOT NULL
        SET @Qry += ' ORDER BY s.ShipRoute, s.RouteOrder, p.PayeeName, s.SalesNumber';
    ELSE
        SET @Qry += ' ORDER BY s.SalesNumber DESC';

    SET @Qry += '
        OFFSET ' + CONVERT(VARCHAR(100), (@PageSize * (@Pageno - 1))) + ' ROWS
        FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY';

    EXEC sp_executesql
        @Qry,
        N'@S NVARCHAR(50), @SearchInt INT, @SearchMoney DECIMAL(18,2)',
        @S = @S,
        @SearchInt = @SearchInt,
        @SearchMoney = @SearchMoney;
END
