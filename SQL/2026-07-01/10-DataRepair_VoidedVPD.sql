-- One-time data repair: Restore VPD amounts for voided payments
-- The old VoidCheck SP zeroed VPD.PaymentApplied/DiscountApplied on void.
-- The new approach preserves VPD amounts and uses IsVoid=0 filter instead.
-- This script restores zeroed VPD amounts so future un-void works correctly.
--
-- Prerequisites: Run 03-VendorPayment_VoidCheck.sql FIRST (stops zeroing VPD)

-- Preview: Show voided payments with zeroed VPD
SELECT
    vp.VendorPaymentId,
    vp.PaymentNumber,
    vp.PaymentAmount,
    vp.PaymentMethod,
    vp.PaymentDate,
    vpd.PaymentDetailId,
    vpd.PurchaseId,
    vpd.PaymentApplied AS [Current VPD PaymentApplied],
    vpd.DiscountApplied AS [Current VPD DiscountApplied],
    BillCount.Cnt AS [Bills in Payment]
FROM VendorPayment vp
INNER JOIN VendorPaymentDetail vpd ON vpd.VendorPaymentId = vp.VendorPaymentId
CROSS APPLY (
    SELECT COUNT(DISTINCT vpd2.PurchaseId) AS Cnt
    FROM VendorPaymentDetail vpd2
    WHERE vpd2.VendorPaymentId = vp.VendorPaymentId
) BillCount
WHERE vp.IsVoid = 1
  AND vpd.PaymentApplied = 0
  AND vp.PaymentAmount > 0
ORDER BY vp.VendorPaymentId;

-- Part A: Restore VPD amounts for SINGLE-BILL voided payments
-- Safe: when only 1 bill, VPD.PaymentApplied = VendorPayment.PaymentAmount - VPD.DiscountApplied
UPDATE vpd
SET vpd.PaymentApplied = vp.PaymentAmount - ISNULL(vpd.DiscountApplied, 0)
FROM VendorPaymentDetail vpd
INNER JOIN VendorPayment vp ON vp.VendorPaymentId = vpd.VendorPaymentId
WHERE vp.IsVoid = 1
  AND vpd.PaymentApplied = 0
  AND vp.PaymentAmount > 0
  AND (SELECT COUNT(DISTINCT vpd2.PurchaseId)
       FROM VendorPaymentDetail vpd2
       WHERE vpd2.VendorPaymentId = vp.VendorPaymentId) = 1;

PRINT 'Single-bill voided payments restored: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' VPD rows';

-- Multi-bill voided payments (VendorPaymentId 1587, 2590, 7261) are already voided
-- and will stay voided — no action needed for those.
