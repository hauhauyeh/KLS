SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- Rollback for BankFeedSource_add_deposit_mode.sql
--   Plan: plan/bank-feed-create-phase-2-open-invoice.md  (Slice 1, D8)
--
-- Restores the 2026-08-06 live baseline of both constraints.
--
-- Refuses while any row still uses 'Deposit' or 'DepositPayments'. Narrowing the constraint
-- under live rows would leave data the table's own CHECK says cannot exist - and every one
-- of those rows points at a real TransferFund deposit and a real journal that Bank Feed
-- generated. Reverse those bank feed rows first, then run this.
-- =============================================================================================

IF EXISTS (SELECT 1 FROM dbo.BankFeedSource
           WHERE [SourceDocType] = 'Deposit' OR [Mode] = 'DepositPayments')
BEGIN
    DECLARE @n INT = (SELECT COUNT(*) FROM dbo.BankFeedSource
                      WHERE [SourceDocType] = 'Deposit' OR [Mode] = 'DepositPayments');
    RAISERROR('Cannot roll back: %d BankFeedSource row(s) still use SourceDocType = ''Deposit'' or Mode = ''DepositPayments''. Reverse those bank feed rows first.', 16, 1, @n);
    SET NOEXEC ON;
END
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_BankFeedSource_SourceDocType'
             AND parent_object_id = OBJECT_ID('dbo.BankFeedSource'))
    ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_SourceDocType;
GO

ALTER TABLE dbo.BankFeedSource ADD CONSTRAINT CK_BankFeedSource_SourceDocType
    CHECK ([SourceDocType] IN ('VendorPayment', 'CustomerPayment'));
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_BankFeedSource_Mode'
             AND parent_object_id = OBJECT_ID('dbo.BankFeedSource'))
    ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_Mode;
GO

ALTER TABLE dbo.BankFeedSource ADD CONSTRAINT CK_BankFeedSource_Mode
    CHECK ([Mode] IN ('PayOpenBill', 'ReceiveOpenInvoice', 'ResolveDifference'));
GO

SET NOEXEC OFF;
GO
