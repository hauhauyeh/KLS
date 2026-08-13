-- 2026-07-13 DROPSHIP-SOREF: project linked SO reference for Bill Manager badge.
-- 2026-08-12 BILL-SEARCH: expand Bill Manager fallback search refs with parameterized search values.
-- 2026-08-12 BILL-DS-CUSTOMER-FILTER: filter Bill Manager by exact linked drop-ship customer id.
-- 2026-08-12 BILL-DS-CHAIN: return drop-ship chain label required by PurchaseList mapping.
CREATE   PROCEDURE [dbo].[Purchase_GetAllList]
    @Pageno INT,
    @Pagesize INT,
    @Search NVARCHAR(50),
    @StartDate DATE,
    @EndDate DATE,
    @VendorId INT,
    @EmpId INT,
    @Filterby NVARCHAR(50),
    @Id INT,
    @SortField NVARCHAR(50),
    @SortOrder NVARCHAR(50),
    @IsCount BIT,
    @DropShipSalesCustomerId INT,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);
    DECLARE @IsAdmin BIT;
    DECLARE @S NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@Search)), '');
    DECLARE @SearchNumber INT = TRY_CONVERT(INT, @S);
    DECLARE @PackageShipmentId INT;

    SELECT @IsAdmin = r.IsAdmin
    FROM dbo.SystemUser AS s
    INNER JOIN dbo.SystemRole AS r ON s.SystemRoleId = r.SystemRoleId
    WHERE s.PayeeId = @EmpId;

    -- 2026-07-20 SHIP-PACKAGE-SEARCH: exact bill/container/factor search can resolve
    -- to one shipment package. The dynamic list then filters by that ShipmentId instead of
    -- only returning the matched bill row. VendorDocNumber stays in normal search because it
    -- can contain multiple loose references separated by spaces, commas, or line breaks.
    IF @S IS NOT NULL
    BEGIN
        DECLARE @PackageCandidates TABLE (ShipmentId INT PRIMARY KEY);

        INSERT INTO @PackageCandidates (ShipmentId)
        SELECT DISTINCT x.ShipmentId
        FROM (
            -- Exact Bill #: goods bills map through ShipmentPurchase; generated charge AP bills
            -- carry their source shipment directly.
            SELECT sp.ShipmentId
            FROM dbo.Purchase p
            INNER JOIN dbo.ShipmentPurchase sp ON sp.PurchaseId = p.PurchaseId
            WHERE @SearchNumber IS NOT NULL
              AND p.PurchaseNumber = @SearchNumber

            UNION

            SELECT p.SourceShipmentId
            FROM dbo.Purchase p
            WHERE @SearchNumber IS NOT NULL
              AND p.PurchaseNumber = @SearchNumber
              AND ISNULL(p.IsShipment, 0) = 1
              AND p.SourceShipmentId IS NOT NULL

            UNION

            -- Exact purchase container / FactorPO on either goods bills or charge AP bills.
            SELECT sp.ShipmentId
            FROM dbo.Purchase p
            INNER JOIN dbo.ShipmentPurchase sp ON sp.PurchaseId = p.PurchaseId
            WHERE p.ContainerNumber = @S
               OR p.FactorPO = @S

            UNION

            SELECT p.SourceShipmentId
            FROM dbo.Purchase p
            WHERE (p.ContainerNumber = @S OR p.FactorPO = @S)
              AND ISNULL(p.IsShipment, 0) = 1
              AND p.SourceShipmentId IS NOT NULL

            UNION

            -- Exact shipment container.
            SELECT s.ShipmentId
            FROM dbo.Shipment s
            WHERE s.ContainerNo = @S
        ) x
        WHERE x.ShipmentId IS NOT NULL;

        IF (SELECT COUNT(*) FROM @PackageCandidates) = 1
            SELECT @PackageShipmentId = ShipmentId FROM @PackageCandidates;
    END

    -- FreightAllocationMethod is for the Bill Manager method badge only.
    -- It reads the current per-bill freight method from ShipmentCharge; exception badges still use the existing flags.
    IF @IsCount = 1
        SET @Qry = 'SELECT @RCount=COUNT(p.PurchaseId)';
    ELSE
        SET @Qry = 'SELECT
        v.PayeeName,
        p.PurchaseId,
        p.PurchaseNumber,
        p.StageId,
        pst.StageName,
        p.PayeeId,
        PurchaseDate,
        EnterDate,
        ArrivalDate,
        InvoiceDate,
        VendorDocNumber,
        p.FactorPO,
        ContainerNumber,
        VendorTotal,
        PurchaseTotal,
        p.AmountDue,
        p.Notes,
        p.IsLocked,
        IsFreightOnly,
        FreightTotal,
        ImportCommission,
        PalletCount,
        CustomDutyTotal,
        psCalc.PaymentStatusId,
        ps.PaymentStatusName,
        p.IsStartFromPO,
        p.IsShipment,
        p.SourceShipmentId,
        vp.IsShippingCarrier,
        p.IsDropShip,
        p.DropShipSalesId,
        dss.SalesNumber AS DropShipSalesNumber,
        dsseq.DropShipChainLabel,
        dss.CustPONumber AS DropShipSalesCustPONumber,
        dss.ShipId AS DropShipSalesCustomerId,
        dsp.PayeeName AS DropShipSalesCustomerName,
        spx.ShipmentLinkCount,
        shipinfo.ShipmentContainerNos,
        shipinfo.ShipmentCarrierName,
        chargebills.ChargeBillCount,
        sps.PurchaseLinkCount,
        CASE
        WHEN EXISTS (
            SELECT 1 FROM PurchaseDetail pd
            WHERE pd.PurchaseId = p.PurchaseId AND pd.LineType = ''I''
              AND pd.ItemId IS NOT NULL
        ) THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
        END AS IsNormalPurchase,
        CASE
        WHEN EXISTS (
            SELECT 1 FROM PurchaseDetail pd
            WHERE pd.PurchaseId = p.PurchaseId
              AND pd.VendorPaymentId IS NOT NULL
        ) THEN CAST(1 AS bit)
        ELSE CAST(0 AS bit)
        END AS IsPayNow,
        -- Phase 2D: HasAllocation = at least one ShipmentAllocation row exists
        -- for this purchase''s linked shipment charges
        CASE WHEN alloc.LastAllocAt IS NOT NULL THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS HasAllocation,
        -- Phase 2D: NeedsReallocation = allocated but item or charge data changed since
        -- Item.UpdatedAt is intentionally broad: any item save triggers this flag
        CASE
            WHEN alloc.LastAllocAt IS NULL THEN CAST(0 AS bit)
            WHEN EXISTS (
                SELECT 1 FROM dbo.PurchaseDetail pd
                JOIN dbo.Item i ON pd.ItemId = i.ItemId
                WHERE pd.PurchaseId = p.PurchaseId
                  AND pd.ItemId IS NOT NULL
                  AND i.UpdatedAt > alloc.LastAllocAt
            ) THEN CAST(1 AS bit)
            WHEN EXISTS (
                SELECT 1 FROM dbo.ShipmentCharge sc
                JOIN dbo.ShipmentPurchase sp2 ON sc.ShipmentId = sp2.ShipmentId
                WHERE sp2.PurchaseId = p.PurchaseId
                  AND sc.UpdatedAt IS NOT NULL
                  AND sc.UpdatedAt > alloc.LastAllocAt
            ) THEN CAST(1 AS bit)
            ELSE CAST(0 AS bit)
        END AS NeedsReallocation,
        -- HasFallback: any allocation row used BY_VALUE_FALLBACK
        CASE
            WHEN alloc.LastAllocAt IS NULL THEN CAST(0 AS bit)
            WHEN EXISTS (
                SELECT 1 FROM dbo.ShipmentAllocation sa
                JOIN dbo.ShipmentCharge sc ON sa.ChargeId = sc.ChargeId
                JOIN dbo.ShipmentPurchase sp3 ON sc.ShipmentId = sp3.ShipmentId
                WHERE sp3.PurchaseId = p.PurchaseId
                  AND sa.AllocationMethod = ''BY_VALUE_FALLBACK''
            ) THEN CAST(1 AS bit)
            ELSE CAST(0 AS bit)
        END AS HasFallback,
        fallback.FallbackMethods,
        (
            SELECT STRING_AGG(fm.AllocationMethod, '', '')
            FROM (
                SELECT DISTINCT sc.AllocationMethod
                FROM dbo.ShipmentPurchase sp4
                JOIN dbo.ShipmentCharge sc ON sc.ShipmentPurchaseId = sp4.ShipmentPurchaseId
                WHERE sp4.PurchaseId = p.PurchaseId
                  AND sc.ChargeType = ''Freight''
                  AND sc.AllocationMethod IS NOT NULL
            ) fm
        ) AS FreightAllocationMethod';

    SET @Qry += ' FROM Purchase AS p INNER JOIN Payee AS v ON p.PayeeId = v.PayeeId
        INNER JOIN Vendor AS vp ON vp.PayeeId = v.PayeeId
        LEFT JOIN PurchaseStage AS pst ON pst.StageId = p.StageId
        LEFT JOIN Sales AS dss ON dss.SalesId = p.DropShipSalesId
        LEFT JOIN Payee AS dsp ON dsp.PayeeId = dss.ShipId
        CROSS APPLY (
        SELECT
            CASE
                -- Positive invoice (normal purchase)
                WHEN p.PurchaseTotal > 0 THEN
                    CASE
                        WHEN ISNULL(p.PaymentApplied, 0) = 0 THEN 5  -- Unpaid
                        WHEN (ISNULL(p.PaymentApplied, 0) + ISNULL(p.DiscountApplied, 0)) <  p.PurchaseTotal THEN 6  -- Partially Paid
                        WHEN (ISNULL(p.PaymentApplied, 0) + ISNULL(p.DiscountApplied, 0)) =  p.PurchaseTotal THEN 7  -- Paid
                        WHEN (ISNULL(p.PaymentApplied, 0) + ISNULL(p.DiscountApplied, 0)) >  p.PurchaseTotal THEN 8  -- Over Paid
                    END

                -- Zero invoice amount
                WHEN p.PurchaseTotal = 0 THEN
                    CASE
                        WHEN (ISNULL(p.PaymentApplied, 0) + ISNULL(p.DiscountApplied, 0)) = 0 THEN 5  -- Unpaid
                        WHEN (ISNULL(p.PaymentApplied, 0) + ISNULL(p.DiscountApplied, 0)) > 0 THEN 8  -- Over Paid
                    END

                -- Negative invoice (credit note)
                WHEN p.PurchaseTotal < 0 THEN
                    CASE
                        WHEN ISNULL(p.PaymentApplied, 0) = 0 THEN 9                           -- Credit
                        WHEN ABS(ISNULL(p.PaymentApplied, 0)) <  ABS(p.PurchaseTotal) THEN 10 -- Credit - Partial
                        WHEN ABS(ISNULL(p.PaymentApplied, 0)) >= ABS(p.PurchaseTotal) THEN 11 -- Credit - Settled
                    END
            END AS PaymentStatusId
        ) AS psCalc LEFT JOIN PaymentStatus AS ps ON ps.PaymentStatusId = psCalc.PaymentStatusId
        OUTER APPLY (
            SELECT
                COUNT(*) AS ShipmentLinkCount
            FROM dbo.ShipmentPurchase sp
            WHERE sp.PurchaseId = p.PurchaseId
        ) spx
        OUTER APPLY (
            -- Previous aggregate kept for reference:
            -- SELECT STRING_AGG(s.ContainerNo, '', '') AS ShipmentContainerNos
            SELECT TOP (1)
                NULLIF(LTRIM(RTRIM(s.ContainerNo)), '''') AS ShipmentContainerNos,
                carrier.PayeeName AS ShipmentCarrierName
            FROM dbo.ShipmentPurchase sp
            INNER JOIN dbo.Shipment s ON sp.ShipmentId = s.ShipmentId
            LEFT JOIN dbo.Payee carrier ON carrier.PayeeId = s.PayeeId
            WHERE sp.PurchaseId = p.PurchaseId
            ORDER BY sp.ShipmentPurchaseId
        ) shipinfo
        OUTER APPLY (
            SELECT COUNT(DISTINCT chargeBill.PurchaseId) AS ChargeBillCount
            FROM dbo.ShipmentPurchase sp
            INNER JOIN dbo.Purchase chargeBill
                ON chargeBill.SourceShipmentId = sp.ShipmentId
               AND ISNULL(chargeBill.IsShipment, 0) = 1
            WHERE sp.PurchaseId = p.PurchaseId
        ) chargebills
        OUTER APPLY (
            SELECT
                COUNT(*) AS PurchaseLinkCount
            FROM dbo.ShipmentPurchase sp
            WHERE sp.ShipmentId = p.SourceShipmentId
        ) sps
        OUTER APPLY (
            SELECT MAX(sa.CreatedAt) AS LastAllocAt
            FROM dbo.ShipmentAllocation sa
            JOIN dbo.ShipmentCharge sc ON sa.ChargeId = sc.ChargeId
            JOIN dbo.ShipmentPurchase sp ON sc.ShipmentId = sp.ShipmentId
            WHERE sp.PurchaseId = p.PurchaseId
        ) alloc';

    SET @Qry += '
        OUTER APPLY (
            SELECT STRING_AGG(REPLACE(sa.AllocationMethod, ''_FALLBACK'', ''''), '', '') AS FallbackMethods
            FROM (
                SELECT DISTINCT sa.AllocationMethod
                FROM dbo.ShipmentAllocation sa
                JOIN dbo.ShipmentCharge sc ON sa.ChargeId = sc.ChargeId
                JOIN dbo.ShipmentPurchase sp ON sc.ShipmentId = sp.ShipmentId
                WHERE sp.PurchaseId = p.PurchaseId
                  AND sa.AllocationMethod LIKE ''%FALLBACK''
            ) sa
        ) fallback
        OUTER APPLY (
            SELECT RootSalesNumber = COALESCE(dss.ParentSalesNumber, dss.SalesNumber)
        ) dsroot
        OUTER APPLY (
            SELECT DropShipChainLabel =
                CASE
                    WHEN ISNULL(p.IsDropShip, 0) = 1
                     AND p.DropShipSalesId IS NOT NULL
                     AND dss.SalesId IS NOT NULL
                     AND seq.ChainIndex > 0
                    THEN CONCAT(
                        seq.ChainIndex,
                        CASE
                            WHEN seq.ChainIndex % 100 BETWEEN 11 AND 13 THEN ''th''
                            WHEN seq.ChainIndex % 10 = 1 THEN ''st''
                            WHEN seq.ChainIndex % 10 = 2 THEN ''nd''
                            WHEN seq.ChainIndex % 10 = 3 THEN ''rd''
                            ELSE ''th''
                        END
                    )
                    ELSE NULL
                END
            FROM (
                SELECT ChainIndex = COUNT(1)
                FROM dbo.Sales AS chainRow
                WHERE dsroot.RootSalesNumber IS NOT NULL
                  AND (chainRow.SalesNumber = dsroot.RootSalesNumber
                       OR chainRow.ParentSalesNumber = dsroot.RootSalesNumber)
                  AND (
                        CASE WHEN chainRow.SalesNumber = dsroot.RootSalesNumber THEN 0 ELSE 1 END
                        < CASE WHEN dss.SalesNumber = dsroot.RootSalesNumber THEN 0 ELSE 1 END
                        OR (
                            CASE WHEN chainRow.SalesNumber = dsroot.RootSalesNumber THEN 0 ELSE 1 END
                            = CASE WHEN dss.SalesNumber = dsroot.RootSalesNumber THEN 0 ELSE 1 END
                            AND chainRow.SalesNumber <= dss.SalesNumber
                        )
                  )
            ) seq
        ) dsseq
        WHERE p.StageId=6';

    IF @Id IS NOT NULL
        SET @Qry += ' AND p.PurchaseId=' + CONVERT(VARCHAR, @Id) + '';

    IF @IsAdmin = 0
        SET @Qry += ' AND vp.IsVisibleToAdmin=0 ';

    IF @VendorId IS NOT NULL
        SET @Qry += ' AND p.PayeeId=' + CONVERT(VARCHAR, @VendorId) + '';

    IF @DropShipSalesCustomerId IS NOT NULL
        SET @Qry += ' AND dss.ShipId = @DropShipSalesCustomerId';

    IF @PackageShipmentId IS NOT NULL
        SET @Qry += ' AND (
            EXISTS (
                SELECT 1
                FROM dbo.ShipmentPurchase packsp
                WHERE packsp.PurchaseId = p.PurchaseId
                  AND packsp.ShipmentId = ' + CONVERT(VARCHAR(20), @PackageShipmentId) + '
            )
            OR (
                ISNULL(p.IsShipment, 0) = 1
                AND p.SourceShipmentId = ' + CONVERT(VARCHAR(20), @PackageShipmentId) + '
            )
        )';
    ELSE IF @S IS NOT NULL
        SET @Qry += ' AND (
            p.VendorDocNumber LIKE ''%'' + @S + ''%''
            OR p.ContainerNumber LIKE ''%'' + @S + ''%''
            OR p.FactorPO LIKE ''%'' + @S + ''%''
            OR dss.CustPONumber LIKE ''%'' + @S + ''%''
            OR (@SearchNumber IS NOT NULL AND p.PurchaseNumber = @SearchNumber)
            OR (@SearchNumber IS NOT NULL AND dss.SalesNumber = @SearchNumber)
        )';

    IF @StartDate IS NOT NULL
        SET @Qry += ' AND p.ArrivalDate>=''' + CONVERT(VARCHAR, @StartDate) + '''';

    IF @EndDate IS NOT NULL
        SET @Qry += ' AND p.ArrivalDate<=''' + CONVERT(VARCHAR, @EndDate) + '''';

    IF @Filterby IS NOT NULL
    BEGIN
        IF @Filterby = 'unpaid'
            SET @Qry += ' AND p.AmountDue!=0';
        ELSE IF @Filterby = 'paid'
            SET @Qry += ' AND p.AmountDue=0';
        ELSE IF @Filterby = 'overdue'
            SET @Qry += ' AND v.PayeePastDue!=0';
        ELSE IF @Filterby = 'notlink'
            SET @Qry += ' AND IsFreightOnly=1 AND p.PurchaseId NOT IN (SELECT FreightBillId FROM FreightBillLink)';
        -- Phase 2D: new filters
        ELSE IF @Filterby = 'needsrealloc'
            SET @Qry += ' AND alloc.LastAllocAt IS NOT NULL
                AND (
                    EXISTS (SELECT 1 FROM dbo.PurchaseDetail pd JOIN dbo.Item i ON pd.ItemId = i.ItemId WHERE pd.PurchaseId = p.PurchaseId AND pd.ItemId IS NOT NULL AND i.UpdatedAt > alloc.LastAllocAt)
                    OR EXISTS (SELECT 1 FROM dbo.ShipmentCharge sc JOIN dbo.ShipmentPurchase sp2 ON sc.ShipmentId = sp2.ShipmentId WHERE sp2.PurchaseId = p.PurchaseId AND sc.UpdatedAt IS NOT NULL AND sc.UpdatedAt > alloc.LastAllocAt)
                )';
        ELSE IF @Filterby = 'unallocated'
            SET @Qry += ' AND spx.ShipmentLinkCount > 0 AND alloc.LastAllocAt IS NULL';
        ELSE IF @Filterby = 'fallback'
            SET @Qry += ' AND alloc.LastAllocAt IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.ShipmentAllocation sa JOIN dbo.ShipmentCharge sc ON sa.ChargeId = sc.ChargeId JOIN dbo.ShipmentPurchase sp3 ON sc.ShipmentId = sp3.ShipmentId WHERE sp3.PurchaseId = p.PurchaseId AND sa.AllocationMethod = ''BY_VALUE_FALLBACK'')';
    END

    IF @IsCount = 1
    BEGIN
        EXEC sp_executesql
            @Qry,
            N'@S NVARCHAR(50), @SearchNumber INT, @DropShipSalesCustomerId INT, @RCount int OUTPUT',
            @S = @S,
            @SearchNumber = @SearchNumber,
            @DropShipSalesCustomerId = @DropShipSalesCustomerId,
            @RCount = @TotalCount OUTPUT;
        RETURN;
    END

    IF @SortField IS NOT NULL
        SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder + '';
    ELSE
    BEGIN
        -- 2026-05-27: reverted to EnterDate per user feedback - see file header.
        -- 2026-05-23: SET @Qry += ' ORDER BY p.ArrivalDate DESC,p.PurchaseNumber DESC';
        IF @S IS NOT NULL
            SET @Qry += ' ORDER BY p.EnterDate DESC,p.PurchaseNumber DESC';
        -- 2026-05-27: reverted to EnterDate per user feedback - see file header.
        -- 2026-05-23: SET @Qry += ' ORDER BY p.ArrivalDate DESC,p.PurchaseNumber DESC';
        ELSE IF @VendorId IS NOT NULL
            SET @Qry += ' ORDER BY p.ArrivalDate DESC,p.PurchaseNumber DESC';
        ELSE
            SET @Qry += ' ORDER BY p.EnterDate DESC,p.PurchaseNumber DESC';
    END

    SET @Qry += ' OFFSET ' + CONVERT(VARCHAR(100), (@PageSize * (@Pageno - 1))) + ' ROWS
    FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY ';

    EXEC sp_executesql
        @Qry,
        N'@S NVARCHAR(50), @SearchNumber INT, @DropShipSalesCustomerId INT',
        @S = @S,
        @SearchNumber = @SearchNumber,
        @DropShipSalesCustomerId = @DropShipSalesCustomerId;
END




