SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ROLLBACK for BankFeedSource_add_rule_transfer_constraints.sql
-- Refuses to roll back while any BankFeedSource row still uses transfer tracing.

IF EXISTS (SELECT 1 FROM dbo.BankFeedSource
           WHERE [SourceDocType] = 'Transfer' OR [Mode] = 'RuleTransfer')
BEGIN
    DECLARE @n INT = (SELECT COUNT(*) FROM dbo.BankFeedSource
                      WHERE [SourceDocType] = 'Transfer' OR [Mode] = 'RuleTransfer');
    RAISERROR('Cannot roll back: %d BankFeedSource row(s) still use SourceDocType = ''Transfer'' or Mode = ''RuleTransfer''. Reverse those bank feed rows first.', 16, 1, @n);
    RETURN;
END;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_BankFeedSource_SourceDocType'
             AND parent_object_id = OBJECT_ID('dbo.BankFeedSource'))
    ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_SourceDocType;
GO

ALTER TABLE dbo.BankFeedSource WITH CHECK ADD CONSTRAINT CK_BankFeedSource_SourceDocType
    CHECK ([SourceDocType] IN ('VendorPayment', 'CustomerPayment', 'Deposit'));
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_BankFeedSource_Mode'
             AND parent_object_id = OBJECT_ID('dbo.BankFeedSource'))
    ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_Mode;
GO

ALTER TABLE dbo.BankFeedSource WITH CHECK ADD CONSTRAINT CK_BankFeedSource_Mode
    CHECK ([Mode] IN ('DepositPayments', 'ResolveDifference', 'ReceiveOpenInvoice',
                      'PayOpenBill', 'LiabilityPayment', 'RuleMoneyIn'));
GO
