SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- BankFeedSource - allow generated rule transfers
-- Plan: plan-03c-bank-feed-rule-transfer-apply.md (Slice 2)
-- Rollback: BankFeedSource_add_rule_transfer_constraints_rollback.sql
--
-- Adds the trace shape used by BankFeed_CreateTransfer:
--   SourceDocType = 'Transfer'    -> generated TransferFund transfer document
--   Mode          = 'RuleTransfer'
-- =============================================================================================

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_BankFeedSource_SourceDocType'
             AND parent_object_id = OBJECT_ID('dbo.BankFeedSource'))
    ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_SourceDocType;
GO

ALTER TABLE dbo.BankFeedSource WITH CHECK ADD CONSTRAINT CK_BankFeedSource_SourceDocType
    CHECK ([SourceDocType] IN ('VendorPayment', 'CustomerPayment', 'Deposit', 'Transfer'));
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_BankFeedSource_Mode'
             AND parent_object_id = OBJECT_ID('dbo.BankFeedSource'))
    ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_Mode;
GO

ALTER TABLE dbo.BankFeedSource WITH CHECK ADD CONSTRAINT CK_BankFeedSource_Mode
    CHECK ([Mode] IN ('DepositPayments', 'ResolveDifference', 'ReceiveOpenInvoice',
                      'PayOpenBill', 'LiabilityPayment', 'RuleMoneyIn', 'RuleTransfer'));
GO
