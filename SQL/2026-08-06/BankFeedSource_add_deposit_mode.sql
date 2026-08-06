SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- BankFeedSource - allow SourceDocType = 'Deposit' and Mode = 'DepositPayments'
--   Plan: plan/bank-feed-create-phase-2-open-invoice.md  (Slice 1, D8)
--
-- Phase 2 handles money-in bank rows. A Customer Payment journal has no bank line
-- (CustomerPayment_Insert posts @UF/@AR only), so the generated, matched, reversible
-- document on the money-in side is the DEPOSIT - a TransferFund row with TFType='DEPOSIT'.
--
--   SourceDocType gains 'Deposit'         - the document Bank Feed generates and matches.
--   Mode          gains 'DepositPayments' - Phase 2a (deposit existing payments).
--                 Phase 2b reuses the existing 'ReceiveOpenInvoice'.
--   SourceDocId holds TransferFund.TFId in both Phase 2 modes.
--
-- Live baseline captured 2026-08-06 (sys.check_constraints):
--   CK_BankFeedSource_SourceDocType: ([SourceDocType]='CustomerPayment' OR [SourceDocType]='VendorPayment')
--   CK_BankFeedSource_Mode:          ([Mode]='ResolveDifference' OR [Mode]='ReceiveOpenInvoice' OR [Mode]='PayOpenBill')
-- Both existing value lists are preserved below - including 'ResolveDifference' (Phase 4b),
-- which the master plan's original spec predates.
--
-- CK_BankFeedSource_Status and UX_BankFeedSource_ActiveDoc are deliberately untouched:
-- Status values do not change, and ('Deposit', TFId) is naturally unique per generated deposit.
--
-- Widening only - existing rows cannot be invalidated. Idempotent. Safe to re-run.
-- Rollback: BankFeedSource_add_deposit_mode_rollback.sql
-- =============================================================================================

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_BankFeedSource_SourceDocType'
             AND parent_object_id = OBJECT_ID('dbo.BankFeedSource'))
    ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_SourceDocType;
GO

ALTER TABLE dbo.BankFeedSource ADD CONSTRAINT CK_BankFeedSource_SourceDocType
    CHECK ([SourceDocType] IN ('VendorPayment', 'CustomerPayment', 'Deposit'));
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_BankFeedSource_Mode'
             AND parent_object_id = OBJECT_ID('dbo.BankFeedSource'))
    ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_Mode;
GO

ALTER TABLE dbo.BankFeedSource ADD CONSTRAINT CK_BankFeedSource_Mode
    CHECK ([Mode] IN ('PayOpenBill', 'ReceiveOpenInvoice', 'ResolveDifference', 'DepositPayments'));
GO
