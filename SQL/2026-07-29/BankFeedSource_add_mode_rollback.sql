SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- Rollback for BankFeedSource_add_mode.sql
--   Plan: plan/bank-feed-create-phase-4b-resolving-lines.md  (Slice 1)
--
-- Refuses while any row still uses 'ResolveDifference'. Narrowing the constraint under live
-- rows would leave data the table's own CHECK says cannot exist - and every one of those rows
-- points at a real VendorPayment and a real journal that Bank Feed generated. Reverse those
-- bank rows first, then run this.
-- =============================================================================================

IF EXISTS (SELECT 1 FROM dbo.BankFeedSource WHERE [Mode] = 'ResolveDifference')
BEGIN
    DECLARE @n INT = (SELECT COUNT(*) FROM dbo.BankFeedSource WHERE [Mode] = 'ResolveDifference');
    RAISERROR('Cannot roll back: %d BankFeedSource row(s) still use Mode = ''ResolveDifference''. Reverse those bank feed rows first.', 16, 1, @n);
    SET NOEXEC ON;
END
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_BankFeedSource_Mode'
             AND parent_object_id = OBJECT_ID('dbo.BankFeedSource'))
    ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_Mode;
GO

ALTER TABLE dbo.BankFeedSource ADD CONSTRAINT CK_BankFeedSource_Mode
    CHECK ([Mode] IN ('PayOpenBill', 'ReceiveOpenInvoice'));
GO

SET NOEXEC OFF;
GO
