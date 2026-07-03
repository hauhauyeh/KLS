-- One-time data repair: Fix PayNow records with PaymentApplied=0
-- These 26 records have valid non-voided PayNow payments but show "Unpaid"
-- because Purchase_CalcTotalAndPercent previously didn't know about PayNow pattern
--
-- IMPORTANT: Only repairs PayNow records. Do NOT touch the 13 non-PayNow records
-- that show "Paid" correctly despite missing VPD backing.
--
-- Prerequisites: Run 01-Purchase_CalcTotalAndPercent.sql FIRST (adds PayNow fallback)

-- Verify count before repair
SELECT 'Before repair' AS [Status], COUNT(DISTINCT p.PurchaseId) AS [PayNow records with PaymentApplied=0]
FROM Purchase p
INNER JOIN PurchaseDetail pd ON pd.PurchaseId = p.PurchaseId AND pd.VendorPaymentId IS NOT NULL
INNER JOIN VendorPayment vp ON vp.VendorPaymentId = pd.VendorPaymentId AND vp.IsVoid = 0
WHERE ISNULL(p.PaymentApplied, 0) = 0;

-- Fix PayNow records by calling the updated CalcTotalAndPercent (which now has PayNow fallback)
DECLARE @FixId INT, @FixTotal DECIMAL(18,2);
DECLARE curFix CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT p.PurchaseId FROM Purchase p
    INNER JOIN PurchaseDetail pd ON pd.PurchaseId = p.PurchaseId AND pd.VendorPaymentId IS NOT NULL
    INNER JOIN VendorPayment vp ON vp.VendorPaymentId = pd.VendorPaymentId AND vp.IsVoid = 0
    WHERE ISNULL(p.PaymentApplied, 0) = 0;
OPEN curFix;
FETCH NEXT FROM curFix INTO @FixId;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC [Purchase_CalcTotalAndPercent] @FixId, @FixTotal OUTPUT;
    PRINT 'Fixed PurchaseId ' + CAST(@FixId AS VARCHAR(10)) + ' → Total: ' + CAST(@FixTotal AS VARCHAR(20));
    FETCH NEXT FROM curFix INTO @FixId;
END
CLOSE curFix;
DEALLOCATE curFix;

-- Verify count after repair (should be 0)
SELECT 'After repair' AS [Status], COUNT(DISTINCT p.PurchaseId) AS [PayNow records with PaymentApplied=0]
FROM Purchase p
INNER JOIN PurchaseDetail pd ON pd.PurchaseId = p.PurchaseId AND pd.VendorPaymentId IS NOT NULL
INNER JOIN VendorPayment vp ON vp.VendorPaymentId = pd.VendorPaymentId AND vp.IsVoid = 0
WHERE ISNULL(p.PaymentApplied, 0) = 0;
