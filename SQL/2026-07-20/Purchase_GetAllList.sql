SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-07-13 DROPSHIP-SOREF: project linked SO reference for Bill Manager badge.
CREATE OR ALTER PROCEDURE [dbo].[Purchase_GetAllList]
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
        p.IsDropShip,
        p.DropShipSalesId,
        dss.SalesNumber AS DropShipSalesNumber,
        dss.CustPONumber AS DropShipSalesCustPONumber,
        spx.ShipmentLinkCount,
        shipinfo.ShipmentContainerNos,
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
            SELECT STRING_AGG(s.ContainerNo, '', '') AS ShipmentContainerNos
            FROM dbo.ShipmentPurchase sp
            INNER JOIN dbo.Shipment s ON sp.ShipmentId = s.ShipmentId
            WHERE sp.PurchaseId = p.PurchaseId
              AND s.ContainerNo IS NOT NULL
              AND LTRIM(RTRIM(s.ContainerNo)) <> ''''
        ) shipinfo
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
        ) alloc
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
        WHERE p.StageId=6';

    IF @Id IS NOT NULL
        SET @Qry += ' AND p.PurchaseId=' + CONVERT(VARCHAR, @Id) + '';

    IF @IsAdmin = 0
        SET @Qry += ' AND vp.IsVisibleToAdmin=0 ';

    IF @VendorId IS NOT NULL
        SET @Qry += ' AND p.PayeeId=' + CONVERT(VARCHAR, @VendorId) + '';

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
    ELSE IF @Search IS NOT NULL
    BEGIN
        IF ISNUMERIC(@Search) = 1
            SET @Qry += ' AND (p.PurchaseNumber=' + @Search + ' OR p.VendorDocNumber=''' + @Search + ''' OR p.ContainerNumber=''' + @Search + ''')';
        ELSE
            SET @Qry += ' AND (p.VendorDocNumber=''' + @Search + ''' OR p.ContainerNumber=''' + @Search + ''')';
    END

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
        EXEC sp_executesql @Qry, N'@RCount int OUTPUT', @RCount = @TotalCount OUTPUT;
        RETURN;
    END

    IF @SortField IS NOT NULL
        SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder + '';
    ELSE
    BEGIN
        -- 2026-05-27: reverted to EnterDate per user feedback - see file header.
        -- 2026-05-23: SET @Qry += ' ORDER BY p.ArrivalDate DESC,p.PurchaseNumber DESC';
        IF @Search IS NOT NULL
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

    EXEC (@Qry);
END
