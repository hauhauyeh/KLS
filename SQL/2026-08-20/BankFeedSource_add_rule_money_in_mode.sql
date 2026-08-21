SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- BankFeedSource - allow Mode = 'RuleMoneyIn'
-- Plan: plan-03b-bank-feed-rule-money-in-apply.md (Slice 2)
-- Rollback: BankFeedSource_add_rule_money_in_mode_rollback.sql
-- =============================================================================================

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_BankFeedSource_Mode'
             AND parent_object_id = OBJECT_ID('dbo.BankFeedSource'))
    ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_Mode;
GO

ALTER TABLE dbo.BankFeedSource WITH CHECK ADD CONSTRAINT CK_BankFeedSource_Mode
    CHECK ([Mode] IN ('DepositPayments', 'ResolveDifference', 'ReceiveOpenInvoice',
                      'PayOpenBill', 'LiabilityPayment', 'RuleMoneyIn'));
GO
