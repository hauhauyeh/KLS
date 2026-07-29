SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- BankFeedSource - allow Mode = 'ResolveDifference'
--   Plan: plan/bank-feed-create-phase-4b-resolving-lines.md  (Slice 1)
--
-- Phase 4b lets a bank row carry a second generated document: a PayNow expense absorbing a
-- bank charge that rode along with the payment. That document is registered here with
-- Mode = 'ResolveDifference'.
--
-- This is the ONLY schema change in Phase 4b.
--
-- SourceDocType is deliberately untouched. A PayNow IS a VendorPayment, so both rows a bank
-- row now carries are SourceDocType = 'VendorPayment' - which is what keeps every Phase 1
-- guard (the Unmatch refusal, the VendorPaymentService delete/save/void guards, and the
-- IsGenerated flag) working with no edit at all.
--
-- UX_BankFeedSource_ActiveDoc is untouched for the same reason: it is unique on
-- (SourceDocType, SourceDocId) and the two rows carry different VendorPaymentIds.
--
-- Idempotent. Safe to re-run. Rollback: BankFeedSource_add_mode_rollback.sql
-- =============================================================================================

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'CK_BankFeedSource_Mode'
             AND parent_object_id = OBJECT_ID('dbo.BankFeedSource'))
    ALTER TABLE dbo.BankFeedSource DROP CONSTRAINT CK_BankFeedSource_Mode;
GO

ALTER TABLE dbo.BankFeedSource ADD CONSTRAINT CK_BankFeedSource_Mode
    CHECK ([Mode] IN ('PayOpenBill', 'ReceiveOpenInvoice', 'ResolveDifference'));
GO
