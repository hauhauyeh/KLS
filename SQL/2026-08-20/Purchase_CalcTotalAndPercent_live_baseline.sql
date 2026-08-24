SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- Fix: Add IsVoid=0 filter on VPD sum + PayNow fallback
-- Bug 1: PayNow has NO VPD rows - VPD sum always returns 0, overwriting correct PaymentApplied
-- Bug 2: Voided payments' VPD amounts (now preserved) must be excluded from sum

-- Purchase_CalcTotalAndPercent codex candidate
-- Baseline: live dbo.Purchase_CalcTotalAndPercent from KLS_Latest
--
-- Summary:
--   Goal: keep Purchase_CalcTotalAndPercent focused on post-posting follow-up
--   work after the core purchase/journal rows are already written.
--
-- Improvements:
--   1. Core totals and base qty no longer belong to this helper
--   2. The old helper-owned logic is kept as commented reference
--   3. This proc remains the owner of payment/due-date/aging/stage follow-up
--      and related maintenance after posting
--
-- What this proc still owns:
--   1. AmountDue / payment / discount follow-up
--   2. DueDate / aging / invoice aging refresh
--   3. Payee aging refresh
--   4. PO stage update
--   5. ItemUnit recent-cost refresh

CREATE   PROCEDURE [dbo].[Purchase_CalcTotalAndPercent]
    @PurchaseId INT,
    @FinalTotal DECIMAL(18,2) OUTPUT
AS
BEGIN
    -- Section 1: initialize working variables for post-posting follow-up.

    SET NOCOUNT ON;

    --Calculate purchase total,aging,freight

    DECLARE @BillTotal DECIMAL(18,2);
    DECLARE @Aging INT = 0;
    DECLARE @InvoiceAging INT = 0;
    DECLARE @DueDate DATE;
    DECLARE @DiscDate DATE;
    DECLARE @DiscRate DECIMAL(18,4);
    DECLARE @AmountDue DECIMAL(18,2);
    DECLARE @PaymentApplied DECIMAL(18,2);
    DECLARE @DiscountApplied DECIMAL(18,2);
    DECLARE @IsLocked BIT = 0;
    DECLARE @IsFreightOnly BIT = 0;
    DECLARE @FreightInside DECIMAL(18,2);
    DECLARE @CustomDutyInside DECIMAL(18,2);
    DECLARE @ArrivalDate DATE;
    DECLARE @TermId INT;
    DECLARE @PayeeId INT;

    -- Section 2: read current persisted purchase detail totals and header context.

    SELECT
        @BillTotal = ISNULL(SUM(ROUND((BillQty * BillPrice), 2)), 0),
        @FinalTotal = ISNULL(SUM(ROUND((FinalQty * FinalPrice), 2)), 0)
    FROM PurchaseDetail
    WHERE PurchaseId = @PurchaseId;

    SELECT
        @ArrivalDate = ArrivalDate,
        @DueDate = DueDate,
        @TermId = TermId,
        @PayeeId = PayeeId
    FROM Purchase
    WHERE PurchaseId = @PurchaseId;

    -- Section 3: refresh due date and aging from the purchase's own stored term
    -- and arrival date.

    IF @DueDate IS NULL
        EXEC Fn_Calc_DueDate
            @ArrivalDate,
            @TermId,
            @DueDate OUTPUT,
            @DiscDate OUTPUT,
            @DiscRate OUTPUT;

    --Calculate Aging

    EXEC Fn_Calc_Aging
        @ArrivalDate,
        @PayeeId,
        @FinalTotal,
        @Aging OUTPUT,
        @InvoiceAging OUTPUT;

    SELECT
        @FreightInside = SUM(ROUND(FinalQty * FinalPrice, 2))
    FROM PurchaseDetail AS pd
    INNER JOIN Account AS a ON a.AccountId = pd.AccountId
    WHERE PurchaseId = @PurchaseId
      AND a.AccountCode IN ('@COGSF', '@INVC');

    SELECT
        @CustomDutyInside = SUM(ROUND(FinalQty * FinalPrice, 2))
    FROM PurchaseDetail AS pd
    INNER JOIN Account AS a ON a.AccountId = pd.AccountId
    WHERE PurchaseId = @PurchaseId
      AND a.AccountCode = '@CD';

    SET @IsFreightOnly =
        IIF(
            EXISTS (SELECT 1 FROM PurchaseDetail WHERE PurchaseId = @PurchaseId)
            AND NOT EXISTS (
                SELECT 1
                FROM PurchaseDetail pd
                LEFT JOIN Account a ON a.AccountId = pd.AccountId
                WHERE pd.PurchaseId = @PurchaseId
                  AND (
                        pd.ItemId IS NOT NULL
                        OR a.AccountId IS NULL
                        OR a.AccountCode NOT IN ('@INVC')
                      )
            ),
            1,
            0
        );

    -- FIX: Add IsVoid=0 filter to exclude voided payments from sum
    SELECT
        @PaymentApplied = ISNULL(SUM(vpd.PaymentApplied), 0),
        @DiscountApplied = ISNULL(SUM(vpd.DiscountApplied), 0)
    FROM VendorPaymentDetail vpd
    INNER JOIN VendorPayment vp ON vp.VendorPaymentId = vpd.VendorPaymentId
    WHERE vpd.PurchaseId = @PurchaseId AND vp.IsVoid = 0;

    -- FIX: PayNow fallback - PayNow has NO VPD rows, payment linked via PurchaseDetail.VendorPaymentId
    IF @PaymentApplied = 0 AND @DiscountApplied = 0
    BEGIN
        SELECT @PaymentApplied = ISNULL(SUM(vp.PaymentAmount), 0)
        FROM (SELECT DISTINCT pd.VendorPaymentId
              FROM PurchaseDetail pd
              WHERE pd.PurchaseId = @PurchaseId AND pd.VendorPaymentId IS NOT NULL) pn
        INNER JOIN VendorPayment vp ON vp.VendorPaymentId = pn.VendorPaymentId
        WHERE vp.IsVoid = 0
    END

    IF (@PaymentApplied != 0 OR @DiscountApplied != 0)
        SET @AmountDue = @FinalTotal - (@PaymentApplied + @DiscountApplied);
    ELSE
        SET @AmountDue = @FinalTotal;

    -- Section 4: core totals and base-qty refresh are no longer owned here.
    -- (kept as comments exactly as original)

    -- Section 5: write post-posting financial follow-up back to Purchase.

    UPDATE Purchase
    SET
        AmountDue = @AmountDue,
        PaymentApplied = @PaymentApplied,
        DiscountApplied = @DiscountApplied,
        Aging = @Aging,
        InvoiceAging = @InvoiceAging,
        DueDate = @DueDate,
        IsFreightOnly = @IsFreightOnly,
        UpdatedAt = GETUTCDATE()
    WHERE PurchaseId = @PurchaseId;

    -- Section 6: run downstream follow-up still owned by this helper.

    EXEC [Payee_UpdateAging] @PayeeId, 0;

    -- Update stage

    UPDATE p
    SET StageId =
        CASE
            WHEN StageId = 6 THEN 6

            -- Drop-ship pre-bill PO stage reflects factory progress only; customer receipt is owned by Order Manager.
            WHEN ISNULL(p.IsDropShip, 0) = 1
              AND p.StageId IN (1, 2, 3, 4, 5)
              AND EXISTS (
                SELECT 1
                FROM PurchaseDetail pd
                WHERE pd.PurchaseId = p.PurchaseId
                  AND ISNULL(pd.ShipQty, 0) > 0
                  AND ItemId IS NOT NULL
            )
            THEN 2

            WHEN ISNULL(p.IsDropShip, 0) = 1
              AND p.StageId IN (1, 2, 3, 4, 5)
            THEN 1

            WHEN NOT EXISTS (
                SELECT 1
                FROM PurchaseDetail pd
                WHERE pd.PurchaseId = p.PurchaseId
                  AND pd.ReceiveQty IS NULL
                  AND ItemId IS NOT NULL
            )
            THEN 5

            WHEN EXISTS (
                SELECT 1
                FROM PurchaseDetail pd
                WHERE pd.PurchaseId = p.PurchaseId
                  AND pd.ReceiveQty IS NOT NULL
                  AND ItemId IS NOT NULL
            )
            THEN 4

            WHEN NOT EXISTS (
                SELECT 1
                FROM PurchaseDetail pd
                WHERE pd.PurchaseId = p.PurchaseId
                  AND pd.ShipQty IS NULL
                  AND ItemId IS NOT NULL
            )
            THEN 3

            WHEN EXISTS (
                SELECT 1
                FROM PurchaseDetail pd
                WHERE pd.PurchaseId = p.PurchaseId
                  AND pd.ShipQty IS NOT NULL
                  AND ItemId IS NOT NULL
            )
            THEN 2

            ELSE 1
        END
    FROM Purchase p
    WHERE p.PurchaseId = @PurchaseId
      AND IsStartFromPO = 1;

    -- 2026-08-12: drop-ship PO factory progress/container moves linked Sales forward to Transit.
    -- Helper no-ops for non-drop-ship purchases and never moves Sales backward.
    EXEC [DropShipment_SyncSalesTransitFromPO] @PurchaseId;

    ----Update ItemUnit RecentCost

    EXEC [ItemUnit_UpdateRecentCost] @PurchaseId,0

END


GO
