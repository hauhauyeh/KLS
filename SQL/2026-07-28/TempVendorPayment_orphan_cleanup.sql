SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- TempVendorPayment - one-off cleanup of orphaned draft rows.
--   Plan: plan/bank-feed-create-phase-1-open-bill.md  (Slice 5 follow-up, 2026-07-28)
--
-- Why these rows exist:
--   VendorPayment_Inject seeds TempVendorPayment whenever a payment is opened in the Vendor
--   Payments screen - one IsApplied=1 row per applied line, plus IsApplied=0 rows for the
--   vendor's other open bills - and stamps each row with that VendorPaymentId. Nothing in the
--   system ever purges the table. When the payment is later deleted (from that screen, or by
--   BankFeed_ReverseVendorPayment), the draft survives its own document.
--
-- Why they matter now:
--   BankFeed_CreateVendorPayment guard 50113 blocks a create while an IsApplied=1 draft exists
--   for (EmpId, PayeeId). An orphaned draft cannot be opened, finished, or discarded from the
--   UI, so it blocked that vendor permanently. Observed on bank feed row 45: create + reverse
--   left 11 rows stamped VendorPaymentId = 11725, one of them IsApplied = 1 for 1,099.27.
--
-- Both leaks are now closed at source:
--   KLS/SQL/2026-07-28/BankFeed_ReverseVendorPayment.sql   step 7 clears its own draft
--   KLS/SQL/2026-07-28/BankFeed_CreateVendorPayment.sql    guard 50113 ignores orphans
-- This script only clears what was stranded before those shipped. Deploy order does not matter.
--
-- Scope - deliberately narrow. It deletes ONLY rows whose VendorPaymentId > 0 and whose payment
-- no longer exists:
--   VendorPaymentId = 0            a genuine new-payment draft. NOT touched.
--   payment still exists           a live edit session someone may still be in. NOT touched.
-- VendorPayment.VendorPaymentId is an IDENTITY column and is never reused, so a non-existent id
-- can only ever mean "deleted", never "not yet created".
--
-- Idempotent: re-running after a clean run deletes nothing.
-- TempVendorPayment has no foreign keys in either direction, so no ordering constraints apply.
-- =============================================================================================

SET NOCOUNT ON;

-- ---------------------------------------------------------------------------------------------
-- 1. Preview. Run this first and read it before running the DELETE below.
--    Expected on KLS-2026 as at 2026-07-28: 11 rows, VendorPaymentId 11725, PayeeId 200917.
--    (VendorPaymentId 11614 has 64 rows / 2 applied but that payment still exists - a live
--     draft, correctly excluded. 34 rows carry VendorPaymentId = 0 - also correctly excluded.)
-- ---------------------------------------------------------------------------------------------
SELECT t.VendorPaymentId,
       t.EmpId,
       t.PayeeId,
       COUNT(*)                        AS RowsToDelete,
       SUM(CAST(t.IsApplied AS INT))   AS AppliedRows,
       SUM(t.PaymentApplied)           AS PaymentApplied,
       SUM(t.DiscountApplied)          AS DiscountApplied
FROM dbo.TempVendorPayment AS t
WHERE t.VendorPaymentId > 0
  AND NOT EXISTS (SELECT 1 FROM dbo.VendorPayment AS vp
                  WHERE vp.VendorPaymentId = t.VendorPaymentId)
GROUP BY t.VendorPaymentId, t.EmpId, t.PayeeId
ORDER BY t.VendorPaymentId DESC;

-- ---------------------------------------------------------------------------------------------
-- 2. The cleanup.
-- ---------------------------------------------------------------------------------------------
BEGIN TRAN;

DELETE t
FROM dbo.TempVendorPayment AS t
WHERE t.VendorPaymentId > 0
  AND NOT EXISTS (SELECT 1 FROM dbo.VendorPayment AS vp
                  WHERE vp.VendorPaymentId = t.VendorPaymentId);

PRINT 'Orphaned TempVendorPayment rows deleted: ' + CAST(@@ROWCOUNT AS VARCHAR(20));

-- Review the count above, then COMMIT. ROLLBACK if it is not what the preview showed.
COMMIT TRAN;
GO

-- ---------------------------------------------------------------------------------------------
-- 3. Verification - the orphan count must be 0, and the live draft for 11614 must survive.
-- ---------------------------------------------------------------------------------------------
SELECT COUNT(*) AS RemainingOrphans
FROM dbo.TempVendorPayment AS t
WHERE t.VendorPaymentId > 0
  AND NOT EXISTS (SELECT 1 FROM dbo.VendorPayment AS vp
                  WHERE vp.VendorPaymentId = t.VendorPaymentId);

SELECT t.VendorPaymentId,
       COUNT(*)                      AS Rows_,
       SUM(CAST(t.IsApplied AS INT)) AS AppliedRows
FROM dbo.TempVendorPayment AS t
GROUP BY t.VendorPaymentId
ORDER BY t.VendorPaymentId DESC;
GO
