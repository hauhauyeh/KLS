-- =============================================================================================
-- ROLLBACK for CK_BankFeedSource_Mode_liabilitypayment.sql
-- Restores the constraint exactly as captured live on 2026-08-19 (before 'LiabilityPayment').
--
-- ONLY safe while no BankFeedSource row has Mode='LiabilityPayment' - reverse any such bank
-- feed rows first, or WITH CHECK below fails on the existing data (which is the correct,
-- loud outcome).
-- =============================================================================================

ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_Mode;
GO

ALTER TABLE dbo.BankFeedSource WITH CHECK ADD CONSTRAINT CK_BankFeedSource_Mode
    CHECK ([Mode]='DepositPayments' OR [Mode]='ResolveDifference'
        OR [Mode]='ReceiveOpenInvoice' OR [Mode]='PayOpenBill');
GO
