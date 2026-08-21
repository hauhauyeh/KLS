SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- LIVE BASELINE 2026-08-20 for BankFeedSource check constraints before 3C transfer apply.
-- Captured from KLS_2026:
--   CK_BankFeedSource_SourceDocType:
--     ([SourceDocType]='Deposit' OR [SourceDocType]='CustomerPayment' OR [SourceDocType]='VendorPayment')
--   CK_BankFeedSource_Mode:
--     ([Mode]='RuleMoneyIn' OR [Mode]='LiabilityPayment' OR [Mode]='PayOpenBill'
--      OR [Mode]='ReceiveOpenInvoice' OR [Mode]='ResolveDifference' OR [Mode]='DepositPayments')

ALTER TABLE dbo.BankFeedSource WITH CHECK ADD CONSTRAINT CK_BankFeedSource_SourceDocType
    CHECK ([SourceDocType] IN ('VendorPayment', 'CustomerPayment', 'Deposit'));
GO

ALTER TABLE dbo.BankFeedSource WITH CHECK ADD CONSTRAINT CK_BankFeedSource_Mode
    CHECK ([Mode] IN ('DepositPayments', 'ResolveDifference', 'ReceiveOpenInvoice',
                      'PayOpenBill', 'LiabilityPayment', 'RuleMoneyIn'));
GO
