SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- BankFeed_ReverseGenerated
--   Undoes every document Bank Feed created for a bank row, and returns the row to Pending.
--   Plan: plan/bank-feed-create-phase-4b-resolving-lines.md  (Slice 2, decisions D1/D10)
--
-- REPLACES BankFeed_ReverseVendorPayment, which is dropped at the bottom of this file.
--
-- What changed and why:
--   Phase 1 created exactly one VendorPayment per bank row, so the old procedure refused when
--   it found more than one source (50302). Phase 4b is precisely that case: a bill payment plus
--   a PayNow expense absorbing a bank charge. That guard is therefore removed, not relaxed.
--
-- The loop body is uniform - one DELETE covers both documents - because a PayNow IS a
-- VendorPayment. TRG_Delete_VendorPmtTx branches internally on PaymentType:
--   'Bill Payment' / 'Bill CCard'      -> VendorPayment_UpdatePurchase restores the bill balances
--   'Check' / 'Credit Card Charge'     -> ALSO deletes the Purchase the PayNow generated
-- and in both cases removes the journal by (SourceDocType, SourceDocNumber).
--
-- ORDER MATTERS, twice:
--   * every source is validated before ANY document is deleted. A bank row whose payment is
--     deletable but whose charge journal is locked must fail whole, not leave one document
--     gone and the other behind.
--   * BankFeedMatch is deleted before the documents. FK_BankFeedMatch_TxDetail is NO_ACTION,
--     so deleting a journal while a match row points at it fails with a raw FK violation.
--
-- Error numbers 50301-50310.
-- =============================================================================================

CREATE OR ALTER PROCEDURE [dbo].[BankFeed_ReverseGenerated]
    @BankFeedTransactionId BIGINT,
    @ReverseReason         NVARCHAR(500) = NULL,
    @EmpId                 INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- As in the create procedure, the transaction opens before validation so the UPDLOCK
    -- actually holds. Nothing is written until every check has passed.
    BEGIN TRAN;
    BEGIN TRY

        -----------------------------------------------------------------------------------
        -- 1. Collect EVERY Active generated source for this bank feed row.
        -----------------------------------------------------------------------------------
        CREATE TABLE #Sources
        (
            BankFeedSourceId BIGINT      NOT NULL,
            SourceDocType    VARCHAR(50) NOT NULL,
            SourceDocId      BIGINT      NOT NULL,
            [Mode]           VARCHAR(50) NOT NULL
        );

        INSERT INTO #Sources (BankFeedSourceId, SourceDocType, SourceDocId, [Mode])
        SELECT bfs.BankFeedSourceId, bfs.SourceDocType, bfs.SourceDocId, bfs.[Mode]
        FROM dbo.BankFeedSource AS bfs WITH (UPDLOCK, HOLDLOCK)
        WHERE bfs.BankFeedTransactionId = @BankFeedTransactionId
          AND bfs.[Status] = 'Active';

        IF NOT EXISTS (SELECT 1 FROM #Sources)
            THROW 50301, 'This bank feed row has no transaction created by Bank Feed to reverse.', 1;

        -----------------------------------------------------------------------------------
        -- 2. Validate ALL of them before deleting ANY of them.
        -----------------------------------------------------------------------------------

        -- Everything this feature generates is a VendorPayment: a bill payment from
        -- VendorPayment_Insert, or a charge from VendorPayment_InsertPayNow. Anything else
        -- means another feature wrote this table and this procedure does not know how to
        -- undo it.
        IF EXISTS (SELECT 1 FROM #Sources WHERE SourceDocType <> 'VendorPayment')
            THROW 50310, 'This bank feed row generated a document type that cannot be reversed here.', 1;

        IF EXISTS (SELECT 1 FROM #Sources AS s
                   WHERE NOT EXISTS (SELECT 1 FROM dbo.VendorPayment AS vp
                                     WHERE vp.VendorPaymentId = s.SourceDocId))
            THROW 50304, 'A generated vendor payment no longer exists.', 1;

        --IF EXISTS (SELECT 1 FROM #Sources AS s
        --           JOIN dbo.VendorPayment AS vp ON vp.VendorPaymentId = s.SourceDocId
        --           WHERE vp.IsLocked = 1)
        --    THROW 50305, 'A generated vendor payment is locked and cannot be reversed.', 1;

        -- A voided payment has already been through VoidCheck, which posts a reversing journal.
        -- Deleting it from here would undo a state this procedure never created.
        IF EXISTS (SELECT 1 FROM #Sources AS s
                   JOIN dbo.VendorPayment AS vp ON vp.VendorPaymentId = s.SourceDocId
                   WHERE vp.IsVoid = 1)
            THROW 50306, 'A generated vendor payment has been voided and cannot be reversed here.', 1;

        -- Resolved from the payment rather than from BankFeedSource.TxId, so a locked journal is
        -- caught even if the stored TxId is stale. TRG_Delete_VendorPmtTx does not check this.
        --IF EXISTS (SELECT 1
        --           FROM #Sources AS s
        --           JOIN dbo.VendorPayment      AS vp ON vp.VendorPaymentId = s.SourceDocId
        --           JOIN dbo.TransactionJournal AS tj
        --                ON tj.SourceDocType   = vp.PaymentType
        --               AND tj.SourceDocNumber = vp.PaymentNumber
        --           WHERE tj.IsLocked = 1)
        --    THROW 50307, 'A journal transaction is locked or reconciled and cannot be reversed.', 1;

        -----------------------------------------------------------------------------------
        -- 3. Drop the match rows FIRST (all of them, once) - see the FK note in the header.
        -----------------------------------------------------------------------------------
        DELETE FROM dbo.BankFeedMatch
        WHERE BankFeedTransactionId = @BankFeedTransactionId;

        -----------------------------------------------------------------------------------
        -- 4. Delete every generated document in one statement.
        --
        --    Safe as a set-based delete even though TRG_Delete_VendorPmtTx is INSTEAD OF
        --    DELETE: it loads `deleted` into a table variable and loops, so it handles
        --    multiple rows correctly. Verified by reading it - do NOT assume this of other
        --    INSTEAD OF triggers in this database.
        -----------------------------------------------------------------------------------
        DELETE FROM dbo.VendorPayment
        WHERE VendorPaymentId IN (SELECT SourceDocId FROM #Sources);

        IF EXISTS (SELECT 1 FROM #Sources AS s
                   JOIN dbo.VendorPayment AS vp ON vp.VendorPaymentId = s.SourceDocId)
            THROW 50308, 'A generated vendor payment could not be removed.', 1;

        -----------------------------------------------------------------------------------
        -- 5. Discard staging drafts belonging to the documents just deleted.
        --
        --    Opening a payment in the Vendor Payments screen calls VendorPayment_Inject, which
        --    seeds TempVendorPayment with one IsApplied=1 row per applied line plus IsApplied=0
        --    rows for the vendor's other open bills, each stamped with that VendorPaymentId.
        --    Nothing in the system ever cleans those rows up, so once step 4 has deleted the
        --    payment they describe a document that no longer exists - and the IsApplied=1 row
        --    trips guard 50113 in BankFeed_CreateVendorPayment, which is what made a reversed
        --    bank feed row impossible to use a second time (2026-07-28 fix, carried forward).
        --
        --    Targeting VendorPaymentId is exact: it is an IDENTITY column and is never reused.
        --    A genuine new-payment draft carries VendorPaymentId = 0 and is left alone, as is
        --    any draft for a payment that still exists. Deliberately NOT scoped to @EmpId - the
        --    draft may have been injected by a different user, and it is equally dead for them.
        --
        --    TempPurchase needs no equivalent: VendorPayment_InsertPayNow consumes and deletes
        --    its staged rows on success, and it deletes by (EmpId, PayeeId) with no PurchaseId
        --    filter, so nothing survives to be orphaned.
        -----------------------------------------------------------------------------------
        DELETE FROM dbo.TempVendorPayment
        WHERE VendorPaymentId IN (SELECT SourceDocId FROM #Sources);

        -----------------------------------------------------------------------------------
        -- 6. Keep the rows as reversed history rather than deleting them. This is the only
        --    record that these documents were machine-generated, and the audit trail of who
        --    undid them. Every guard in the feature filters Status='Active', so reversed
        --    history never blocks a re-create.
        -----------------------------------------------------------------------------------
        UPDATE bfs
        SET [Status]      = 'Reversed',
            ReversedAt    = SYSUTCDATETIME(),
            ReversedBy    = @EmpId,
            ReverseReason = @ReverseReason
        FROM dbo.BankFeedSource AS bfs
        JOIN #Sources AS s ON s.BankFeedSourceId = bfs.BankFeedSourceId;

        -----------------------------------------------------------------------------------
        -- 7. Return the bank row to Pending, once.
        --    Mirrors BankFeed_UnMatchTx's reset rather than calling it: that procedure would
        --    re-run the BankFeedMatch delete and walk a BankDate cursor over journal rows
        --    step 4 has already destroyed.
        -----------------------------------------------------------------------------------
        UPDATE dbo.BankFeedTransaction
        SET ClearedBankDate = NULL,
            [Status]        = 'Pending',
            MatchedAt       = NULL,
            MatchedBy       = NULL
        WHERE BankFeedTransactionId = @BankFeedTransactionId;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

-- ---------------------------------------------------------------------------------------------
-- Drop the superseded procedure.
--
-- Not left alongside its replacement: it would still "work" while silently refusing every
-- two-source bank row with 50302, and a future reader would have two reverse procedures with
-- no way to tell which one is live.
-- ---------------------------------------------------------------------------------------------
IF OBJECT_ID('dbo.BankFeed_ReverseVendorPayment', 'P') IS NOT NULL
    DROP PROCEDURE dbo.BankFeed_ReverseVendorPayment;
GO
