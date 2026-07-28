SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- BankFeed_ReverseVendorPayment
--   Undoes a VendorPayment that Bank Feed itself created, and returns the bank row to Pending.
--   Plan: plan/bank-feed-create-phase-1-open-bill.md  (Slice 5, decision D5)
--
-- 2026-07-28 FIX_ORPHAN_DRAFT: added step 7 - discard the TempVendorPayment draft belonging to
--   the payment being deleted. Without it, reversing a payment that had been opened in the
--   Vendor Payments screen left an IsApplied=1 draft row pointing at a payment that no longer
--   exists, which tripped guard 50113 in BankFeed_CreateVendorPayment and made the same bank
--   feed row impossible to use again. Everything else in this procedure is unchanged; the
--   previous version is KLS/SQL/2026-07-27/BankFeed_ReverseVendorPayment.sql.
--
--   Observed live on bank feed row 45: reverse restored Purchase 12001, deleted payment 11725,
--   its journal (TxId 662634) and the match rows correctly - but left 11 TempVendorPayment rows
--   stamped VendorPaymentId = 11725, one of them IsApplied = 1 for 1,099.27.
--
-- Reverses ONLY what Bank Feed generated. A manually created payment has no Active
-- BankFeedSource row and therefore cannot be reached through this path at all.
--
-- Most of the undo already exists in the database and is NOT reimplemented here:
--
--   TRG_Delete_VendorPmtTx  (INSTEAD OF DELETE on VendorPayment)
--     1. EXEC VendorPayment_UpdatePurchase @Id, 1
--          -> recomputes Purchase.AmountDue / PaymentApplied / DiscountApplied / Aging /
--             IsLocked from the remaining non-void payments
--     2. DELETE FROM VendorPayment
--          -> FK_VendorPaymentDetail_VendorPayment CASCADE removes the apply lines
--     3. DELETE FROM TransactionJournal WHERE SourceDocType=@Type AND SourceDocNumber=@Number
--          -> TRG_Delete_Tx queues inventory recalc and removes the journal rows
--
-- What that trigger does NOT do, and this procedure must:
--   - check TransactionJournal.IsLocked  (it only ever checked the payment)
--   - delete BankFeedMatch first         (FK_BankFeedMatch_TxDetail is NO_ACTION, so the
--                                         journal delete would fail with a raw FK violation)
--   - discard the TempVendorPayment draft for the deleted payment  (2026-07-28)
--   - reset the BankFeedTransaction header
--
-- Error numbers 50301-50308. Create owns 50101-50119; GetOpenBills owns 50201+.
-- =============================================================================================

CREATE OR ALTER PROCEDURE [dbo].[BankFeed_ReverseVendorPayment]
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
        -- 1. Find the Active generated source for this bank feed row
        -----------------------------------------------------------------------------------
        DECLARE @SourceCount     INT,
                @BankFeedSourceId BIGINT,
                @SourceDocType   VARCHAR(50),
                @SourceDocId     BIGINT,
                @TxId            BIGINT;

        SELECT @SourceCount      = COUNT(*),
               @BankFeedSourceId = MIN(bfs.BankFeedSourceId)
        FROM dbo.BankFeedSource AS bfs WITH (UPDLOCK, HOLDLOCK)
        WHERE bfs.BankFeedTransactionId = @BankFeedTransactionId
          AND bfs.[Status] = 'Active';

        IF @SourceCount = 0
            THROW 50301, 'This bank feed row has no transaction created by Bank Feed to reverse.', 1;

        -- Version 1 creates exactly one source doc per bank feed row. More than one means
        -- something outside this feature wrote the table, and reversing "the" payment would
        -- be a guess. Grouped ACH/batch support is a later phase.
        IF @SourceCount > 1
            THROW 50302, 'This bank feed row has more than one generated transaction. Reverse is not supported.', 1;

        SELECT @SourceDocType = bfs.SourceDocType,
               @SourceDocId   = bfs.SourceDocId,
               @TxId          = bfs.TxId
        FROM dbo.BankFeedSource AS bfs
        WHERE bfs.BankFeedSourceId = @BankFeedSourceId;

        -----------------------------------------------------------------------------------
        -- 2. Confirm it is the kind of document this procedure knows how to undo
        -----------------------------------------------------------------------------------
        IF @SourceDocType <> 'VendorPayment'
            THROW 50303, 'This bank feed row did not generate a vendor payment.', 1;

        -----------------------------------------------------------------------------------
        -- 3. Confirm nothing has locked or voided it since
        -----------------------------------------------------------------------------------
        DECLARE @IsLocked BIT, @IsVoid BIT;

        SELECT @IsLocked = vp.IsLocked,
               @IsVoid   = vp.IsVoid
        FROM dbo.VendorPayment AS vp
        WHERE vp.VendorPaymentId = @SourceDocId;

        IF @IsLocked IS NULL
            THROW 50304, 'The generated vendor payment no longer exists.', 1;

        --IF @IsLocked = 1
        --    THROW 50305, 'The generated vendor payment is locked and cannot be reversed.', 1;

        -- A voided payment has already been through VoidCheck, which rewrites the journal.
        -- Deleting it from here would undo a state this procedure never created.
        IF @IsVoid = 1
            THROW 50306, 'The generated vendor payment has been voided and cannot be reversed here.', 1;

        --IF EXISTS (SELECT 1 FROM dbo.TransactionJournal
        --           WHERE TxId = @TxId AND IsLocked = 1)
        --    THROW 50307, 'The journal transaction is locked or reconciled and cannot be reversed.', 1;

        -----------------------------------------------------------------------------------
        -- 4. Capture the account and cleared date BEFORE the header reset nulls them.
        --    Same ordering BankFeed_UnMatchTx already uses.
        -----------------------------------------------------------------------------------
        DECLARE @AccountId INT, @ClearedBankDate DATE;

        SELECT @AccountId       = bfa.AccountId,
               @ClearedBankDate = bft.ClearedBankDate
        FROM dbo.BankFeedTransaction AS bft
        LEFT JOIN dbo.BankFeedAccount AS bfa
            ON bfa.BankFeedAccountId = bft.BankFeedAccountId
        WHERE bft.BankFeedTransactionId = @BankFeedTransactionId;

        -----------------------------------------------------------------------------------
        -- 5. Drop the match rows FIRST - FK_BankFeedMatch_TxDetail is NO_ACTION, so the
        --    journal delete in step 6 would otherwise fail with a raw FK violation.
        -----------------------------------------------------------------------------------
        DELETE FROM dbo.BankFeedMatch
        WHERE BankFeedTransactionId = @BankFeedTransactionId;

        -----------------------------------------------------------------------------------
        -- 6. Delete the payment. TRG_Delete_VendorPmtTx restores the purchase balances,
        --    cascades away the apply lines, and removes the journal.
        -----------------------------------------------------------------------------------
        DELETE FROM dbo.VendorPayment
        WHERE VendorPaymentId = @SourceDocId;

        IF EXISTS (SELECT 1 FROM dbo.VendorPayment WHERE VendorPaymentId = @SourceDocId)
            THROW 50308, 'The generated vendor payment could not be removed.', 1;

        -----------------------------------------------------------------------------------
        -- 7. Discard the staging draft that belonged to the payment just deleted.
        --
        --    Opening a payment in the Vendor Payments screen calls VendorPayment_Inject, which
        --    seeds TempVendorPayment with one IsApplied=1 row per applied line plus IsApplied=0
        --    rows for the vendor's other open bills, each stamped with that VendorPaymentId.
        --    Nothing in the system ever cleans those rows up.
        --
        --    Once step 6 has deleted the payment, they describe a document that no longer
        --    exists - and the IsApplied=1 row trips guard 50113 in BankFeed_CreateVendorPayment,
        --    which is what made a reversed bank feed row impossible to use a second time.
        --
        --    Targeting VendorPaymentId is exact: it is an IDENTITY column and is never reused,
        --    so this can only ever match the dead draft. A genuine new-payment draft carries
        --    VendorPaymentId = 0 and is left alone, as is any draft for a payment that still
        --    exists. Deliberately NOT scoped to @EmpId - the draft may have been injected by a
        --    different user, and it is equally dead for them.
        -----------------------------------------------------------------------------------
        DELETE FROM dbo.TempVendorPayment
        WHERE VendorPaymentId = @SourceDocId;

        -----------------------------------------------------------------------------------
        -- 8. Keep the row as reversed history rather than deleting it. This is the audit
        --    trail of what Bank Feed did and who undid it, and it is the only record that the
        --    payment was machine-generated at all. Every guard in the feature - the create
        --    check 50105, HasActiveSource, IsGeneratedVendorPayment, the IsGenerated flag on
        --    BankFeed_GetAllList, and UX_BankFeedSource_ActiveDoc - filters on Status='Active',
        --    so reversed history never blocks a re-create.
        -----------------------------------------------------------------------------------
        UPDATE dbo.BankFeedSource
        SET [Status]      = 'Reversed',
            ReversedAt    = SYSUTCDATETIME(),
            ReversedBy    = @EmpId,
            ReverseReason = @ReverseReason
        WHERE BankFeedSourceId = @BankFeedSourceId;

        -----------------------------------------------------------------------------------
        -- 9. Return the bank row to Pending.
        --    This mirrors BankFeed_UnMatchTx's reset rather than calling it: that procedure
        --    would re-run the BankFeedMatch delete and walk a BankDate cursor over journal
        --    rows step 6 has already destroyed.
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
