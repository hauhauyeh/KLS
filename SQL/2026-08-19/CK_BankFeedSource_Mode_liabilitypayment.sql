-- =============================================================================================
-- CK_BankFeedSource_Mode - add 'LiabilityPayment' to the allowed Mode set.
--   Plan: plan/bank-feed-liability-payment-v1.md  (Slice 1, decision D7)
--
-- The Bank Feed liability-payment create registers its generated VendorPayment with
-- Mode='LiabilityPayment'. The live constraint (captured 2026-08-19, precheck) is:
--   ([Mode]='DepositPayments' OR [Mode]='ResolveDifference'
--    OR [Mode]='ReceiveOpenInvoice' OR [Mode]='PayOpenBill')
-- This script re-creates it with the one extra value. WITH CHECK validates existing rows,
-- which all use the four old values, so the add cannot fail on data.
--
-- Rollback: CK_BankFeedSource_Mode_liabilitypayment_rollback.sql (restores the captured
-- definition; only safe while no 'LiabilityPayment' rows exist - reverse those first).
-- =============================================================================================

ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_Mode;
GO

ALTER TABLE dbo.BankFeedSource WITH CHECK ADD CONSTRAINT CK_BankFeedSource_Mode
    CHECK ([Mode]='DepositPayments' OR [Mode]='ResolveDifference'
        OR [Mode]='ReceiveOpenInvoice' OR [Mode]='PayOpenBill'
        OR [Mode]='LiabilityPayment');   -- LIABILITY_PAYMENT 2026-08-19
GO
