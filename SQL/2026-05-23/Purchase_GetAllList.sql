/*
    Purchase_GetAllList.sql
    2026-05-23

    Single change from baseline: ORDER BY for the default (no @SortField) path
    switched from EnterDate DESC -> ArrivalDate DESC.

    Affects:
      - Recent filter (no search, no sort field): ORDER BY p.ArrivalDate DESC, p.PurchaseNumber DESC
      - Default with search:                       ORDER BY p.ArrivalDate DESC, p.PurchaseNumber DESC

    Why: EnterDate can be backdated by VendorPayment_InsertPayNow (admin Excel
    import path), causing bulk-imported rows to bury themselves mid-list under
    the Recent view. ArrivalDate reflects the meaningful business date and
    is consistent with the new combined date column display in the Bill
    Manager UI.

    No functional logic change beyond the sort order.
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Purchase_GetAllList];
GO
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
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);
    DECLARE @IsAdmin BIT;

    SELECT @IsAdmin = r.IsAdmin
    FROM dbo.SystemUser AS s
    INNER JOIN dbo.SystemRole AS r ON s.SystemRoleId = r.SystemRoleId
    WHERE s.PayeeId = @EmpId;

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
        ContainerNumber,
        VendorTotal,
        PurchaseTotal,
        AmountDue,
        p.Notes,
        IsLocked,
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
        fallback.FallbackMethods';

    SET @Qry += ' FROM Purchase AS p INNER JOIN Payee AS v ON p.PayeeId = v.PayeeId
        INNER JOIN Vendor AS vp ON vp.PayeeId = v.PayeeId
        LEFT JOIN PurchaseStage AS pst ON pst.StageId = p.StageId
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

    IF @Search IS NOT NULL
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
        IF @Search IS NOT NULL
            SET @Qry += ' ORDER BY p.ArrivalDate DESC,p.PurchaseNumber DESC';
        ELSE
            SET @Qry += ' ORDER BY p.ArrivalDate DESC,p.PurchaseNumber DESC';
    END

    SET @Qry += ' OFFSET ' + CONVERT(VARCHAR(100), (@PageSize * (@Pageno - 1))) + ' ROWS
    FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY ';

    EXEC (@Qry);
END
