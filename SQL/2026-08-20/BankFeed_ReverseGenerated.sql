SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================================================================
-- BankFeed_ReverseGenerated
--   Undoes every document Bank Feed created for a bank row, and returns the row to Pending.
--   Plan: plan/bank-feed-create-phase-4b-resolving-lines.md  (Slice 2, decisions D1/D10)
--
-- 2026-08-06 Phase 2a (plan/bank-feed-create-phase-2-open-invoice.md, Slice 5):
--   The procedure now also reverses a generated DEPOSIT (SourceDocType 'Deposit',
--   SourceDocId = TransferFund.TFId). The 50310 guard becomes the dispatch seam: it
--   previously refused everything except 'VendorPayment'; now 'Deposit' takes its own branch.
--
--   The Deposit unwind is trigger-driven and needs almost nothing here (verified live
--   2026-08-06): TRG_Delete_TFTx (INSTEAD OF DELETE on TransferFund) resets
--   CustomerPayment.IsLocked = 0 for every payment in the deposit, deletes the 'Deposit'
--   TransactionJournal rows by TFNumber, and FK_TransferFundDetail_TransferFund cascades the
--   detail rows. The journal delete flows through TRG_Delete_Tx, which queues RecalculationLog
--   only for @INV lines - a deposit journal has none, so no recalc side effect. The whole
--   unwind is DELETE TransferFund; do NOT reset IsLocked, delete TransferFundDetail, or
--   delete the journal by hand - the trigger owns all three.
--
--   The Phase 1/4b VendorPayment validations are now scoped to SourceDocType='VendorPayment'
--   (previously they ran unscoped - correct when nothing else could exist, wrong once a
--   Deposit row can). No VendorPayment behaviour changes.
--
--   The payments INSIDE a 2a deposit (Mode 'DepositPayments') are not deleted - they existed
--   before Bank Feed touched them and return to the undeposited pool.
--
-- 2026-08-06 Phase 2b (same plan, Slice 9): a 'ReceiveOpenInvoice' deposit ALSO deletes the
--   CustomerPayment Bank Feed generated - it did not exist before, and leaving it would
--   strand the amount in @UF forever. Mode is the dispatch: 'DepositPayments' keeps its
--   payments, 'ReceiveOpenInvoice' deletes them. ORDER: the payment ids are captured from
--   TransferFundDetail during validation (the FK cascade wipes that link when the
--   TransferFund goes), and the payments are deleted AFTER the TransferFund, so no detail
--   row ever points at a dead payment. TRG_Delete_CustomerPaymentTx then restores the Sales
--   balances and deletes the payment journal (verified multi-row safe - it loops a table
--   variable, like the other two triggers). Its source-credit refusal is a raw RAISERROR +
--   ROLLBACK, so 50315 pre-checks the same condition for a clean fail-whole error instead.
--
-- What changed in 4b and why:
--   Phase 1 created exactly one VendorPayment per bank row, so the old procedure refused when
--   it found more than one source (50302). Phase 4b is precisely that case: a bill payment plus
--   a PayNow expense absorbing a bank charge. That guard is therefore removed, not relaxed.
--
-- The VendorPayment loop body is uniform - one DELETE covers both documents - because a
-- PayNow IS a VendorPayment. TRG_Delete_VendorPmtTx branches internally on PaymentType:
--   'Bill Payment' / 'Bill CCard'      -> VendorPayment_UpdatePurchase restores the bill balances
--   'Check' / 'Credit Card Charge'     -> ALSO deletes the Purchase the PayNow generated
-- and in both cases removes the journal by (SourceDocType, SourceDocNumber).
--
-- ORDER MATTERS, twice:
--   * every source is validated before ANY document is deleted. A bank row whose payment is
--     deletable but whose charge journal is locked must fail whole, not leave one document
--     gone and the other behind.
--   * BankFeedMatch is deleted before the documents. FK_BankFeedMatch_TxDetail is NO_ACTION,
--     so deleting a journal while a match row points at it fails with a raw FK violation -
--     and for a Deposit the journal delete happens INSIDE TRG_Delete_TFTx, so the match rows
--     must already be gone when the TransferFund delete fires.
--
-- Error numbers 50301-50321 (50311-50314 added 2026-08-06 for the Deposit branch;
-- 50315-50316 added 2026-08-06 for the 2b generated-payment delete; 50317-50318
-- added 2026-08-20 for RuleMoneyIn incoming-payment validation; 50319-50321 added
-- 2026-08-20 for RuleTransfer validation/delete).
--
-- 2026-08-20 RuleMoneyIn (plan-03b-bank-feed-rule-money-in-apply.md, Slice 2):
--   Bank Feed rule-created money-in uses IncomingPayment_Insert, which creates a
--   CustomerPayment row with PaymentType='Other Incoming Payment' and posts the matching
--   journal. BankFeedSource tracks it as SourceDocType='CustomerPayment',
--   Mode='RuleMoneyIn'. Reverse validates that exact pair, deletes BankFeedMatch first,
--   then deletes the CustomerPayment so TRG_Delete_CustomerPaymentTx removes the
--   'Other Incoming Payment' journal.
--
-- 2026-08-20 RuleTransfer (plan-03c-bank-feed-rule-transfer-apply.md, Slice 3):
--   Bank Feed rule-created transfers use TransferFund_Insert, which creates a TransferFund
--   row and a journal with SourceDocType='Transfer'. BankFeedSource tracks it as
--   SourceDocType='Transfer', Mode='RuleTransfer'. Reverse deletes BankFeedMatch first,
--   then deletes the TransferFund so TRG_Delete_TFTx removes the 'Transfer' journal.
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

        -- Everything this feature generates is a VendorPayment (bill payment or PayNow
        -- charge), a Deposit, a rule-created CustomerPayment, or a rule-created Transfer.
        -- Anything else means another feature wrote this table and this procedure does not
        -- know how to undo it.
        -- 2026-08-06: was  WHERE SourceDocType <> 'VendorPayment'
        IF EXISTS (SELECT 1 FROM #Sources WHERE SourceDocType NOT IN ('VendorPayment', 'Deposit', 'CustomerPayment', 'Transfer'))
            THROW 50310, 'This bank feed row generated a document type that cannot be reversed here.', 1;

        IF EXISTS (SELECT 1 FROM #Sources
                   WHERE SourceDocType = 'CustomerPayment'
                     AND [Mode] <> 'RuleMoneyIn')
            THROW 50310, 'This bank feed row generated a customer payment type that cannot be reversed here.', 1;

        IF EXISTS (SELECT 1 FROM #Sources
                   WHERE SourceDocType = 'Transfer'
                     AND [Mode] <> 'RuleTransfer')
            THROW 50310, 'This bank feed row generated a transfer type that cannot be reversed here.', 1;

        -- 2026-08-06: scoped to VendorPayment sources; a Deposit's SourceDocId is a TFId and
        -- must not be looked up in VendorPayment.
        IF EXISTS (SELECT 1 FROM #Sources AS s
                   WHERE s.SourceDocType = 'VendorPayment'
                     AND NOT EXISTS (SELECT 1 FROM dbo.VendorPayment AS vp
                                     WHERE vp.VendorPaymentId = s.SourceDocId))
            THROW 50304, 'A generated vendor payment no longer exists.', 1;

        --IF EXISTS (SELECT 1 FROM #Sources AS s
        --           JOIN dbo.VendorPayment AS vp ON vp.VendorPaymentId = s.SourceDocId
        --           WHERE vp.IsLocked = 1)
        --    THROW 50305, 'A generated vendor payment is locked and cannot be reversed.', 1;

        -- A voided payment has already been through VoidCheck, which posts a reversing journal.
        -- Deleting it from here would undo a state this procedure never created.
        -- (Join to VendorPayment scopes this to VendorPayment sources by construction.)
        IF EXISTS (SELECT 1 FROM #Sources AS s
                   JOIN dbo.VendorPayment AS vp ON vp.VendorPaymentId = s.SourceDocId
                   WHERE s.SourceDocType = 'VendorPayment'
                     AND vp.IsVoid = 1)
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
        -- 2a. Deposit-source validation (2026-08-06). Same fail-whole principle: nothing is
        --     deleted until every source of every type has passed.
        -----------------------------------------------------------------------------------
        IF EXISTS (SELECT 1 FROM #Sources AS s
                   WHERE s.SourceDocType = 'Deposit'
                     AND NOT EXISTS (SELECT 1 FROM dbo.TransferFund AS tf
                                     WHERE tf.TFId = s.SourceDocId))
            THROW 50311, 'The generated deposit no longer exists.', 1;

        -- 50312/50313 DISABLED 2026-08-06, same reason 50305/50307 are disabled above and
        -- proven by the first real reverse attempt: BankFeed_MatchTx sets the journal
        -- BankDate through Transaction_UpdateBankDate, which sets IsLocked = 1 on BOTH the
        -- journal and the TransferFund the moment the deposit is matched. Being matched IS
        -- being locked here, so these guards refused every deposit this feature creates.
        -- The lock bit cannot distinguish "locked by our own match" from "locked by bank
        -- reconciliation"; Phase 1 accepted the same trade-off for VendorPayment.
        --IF EXISTS (SELECT 1 FROM #Sources AS s
        --           JOIN dbo.TransferFund AS tf ON tf.TFId = s.SourceDocId
        --           WHERE s.SourceDocType = 'Deposit'
        --             AND tf.IsLocked = 1)
        --    THROW 50312, 'The generated deposit is locked and cannot be reversed.', 1;

        --IF EXISTS (SELECT 1
        --           FROM #Sources AS s
        --           JOIN dbo.TransferFund       AS tf ON tf.TFId = s.SourceDocId
        --           JOIN dbo.TransactionJournal AS tj
        --                ON tj.SourceDocType   = 'Deposit'
        --               AND tj.SourceDocNumber = tf.TFNumber
        --           WHERE s.SourceDocType = 'Deposit'
        --             AND tj.IsLocked = 1)
        --    THROW 50313, 'The deposit journal is locked or reconciled and cannot be reversed.', 1;

        -----------------------------------------------------------------------------------
        -- 2a1. Rule-created incoming-payment validation (2026-08-20). Only the exact
        --      CustomerPayment shape created by BankFeed_CreateRuleMoneyIn is reversible
        --      here; normal customer payments stay out of this path.
        -----------------------------------------------------------------------------------
        IF EXISTS (SELECT 1 FROM #Sources AS s
                   WHERE s.SourceDocType = 'CustomerPayment'
                     AND NOT EXISTS (SELECT 1 FROM dbo.CustomerPayment AS cp
                                     WHERE cp.CustomerPaymentId = s.SourceDocId))
            THROW 50317, 'The generated incoming payment no longer exists.', 1;

        IF EXISTS (SELECT 1
                   FROM #Sources AS s
                   JOIN dbo.CustomerPayment AS cp
                        ON cp.CustomerPaymentId = s.SourceDocId
                   WHERE s.SourceDocType = 'CustomerPayment'
                     AND s.[Mode] = 'RuleMoneyIn'
                     AND cp.PaymentType <> 'Other Incoming Payment')
            THROW 50318, 'The generated incoming payment is not an Other Incoming Payment and cannot be reversed here.', 1;

        -----------------------------------------------------------------------------------
        -- 2a2. Rule-created transfer validation (2026-08-20). Only the exact TransferFund
        --      shape created by BankFeed_CreateTransfer is reversible here.
        -----------------------------------------------------------------------------------
        IF EXISTS (SELECT 1 FROM #Sources AS s
                   WHERE s.SourceDocType = 'Transfer'
                     AND NOT EXISTS (SELECT 1 FROM dbo.TransferFund AS tf
                                     WHERE tf.TFId = s.SourceDocId))
            THROW 50319, 'The generated transfer no longer exists.', 1;

        IF EXISTS (SELECT 1
                   FROM #Sources AS s
                   JOIN dbo.TransferFund AS tf
                        ON tf.TFId = s.SourceDocId
                   WHERE s.SourceDocType = 'Transfer'
                     AND s.[Mode] = 'RuleTransfer'
                     AND tf.TFType NOT IN ('BK2BK', 'BK2PC', 'PC2PC', 'PC2BK'))
            THROW 50320, 'The generated transfer is not a Bank/Cash transfer and cannot be reversed here.', 1;

        -----------------------------------------------------------------------------------
        -- 2b. Capture the payments a 'ReceiveOpenInvoice' deposit generated, BEFORE the
        --     TransferFund delete cascades TransferFundDetail away (2026-08-06). 2a
        --     'DepositPayments' deposits are deliberately absent - their payments stay.
        -----------------------------------------------------------------------------------
        CREATE TABLE #GeneratedPayments (CustomerPaymentId INT PRIMARY KEY);

        INSERT INTO #GeneratedPayments (CustomerPaymentId)
        SELECT DISTINCT tfd.CustomerPaymentId
        FROM #Sources AS s
        JOIN dbo.TransferFundDetail AS tfd ON tfd.TFId = s.SourceDocId
        WHERE s.SourceDocType = 'Deposit'
          AND s.[Mode] = 'ReceiveOpenInvoice';

        INSERT INTO #GeneratedPayments (CustomerPaymentId)
        SELECT DISTINCT CAST(s.SourceDocId AS INT)
        FROM #Sources AS s
        WHERE s.SourceDocType = 'CustomerPayment'
          AND s.[Mode] = 'RuleMoneyIn'
          AND NOT EXISTS (SELECT 1 FROM #GeneratedPayments AS gp
                          WHERE gp.CustomerPaymentId = CAST(s.SourceDocId AS INT));

        -- Pre-check TRG_Delete_CustomerPaymentTx's refusal condition: another payment used
        -- this one as source credit. The trigger would RAISERROR + ROLLBACK mid-delete;
        -- failing here keeps the fail-whole contract and gives a message naming the cause.
        IF EXISTS (SELECT 1
                   FROM dbo.CustomerPaymentDetail AS pd
                   JOIN #GeneratedPayments AS gp
                        ON gp.CustomerPaymentId = pd.SourceCustomerPaymentId
                   WHERE NOT EXISTS (SELECT 1 FROM #GeneratedPayments AS gp2
                                     WHERE gp2.CustomerPaymentId = pd.CustomerPaymentId))
            THROW 50315, 'The generated customer payment has been used as credit by another payment and cannot be reversed.', 1;

        -----------------------------------------------------------------------------------
        -- 3. Drop the match rows FIRST (all of them, once) - see the FK note in the header.
        -----------------------------------------------------------------------------------
        DELETE FROM dbo.BankFeedMatch
        WHERE BankFeedTransactionId = @BankFeedTransactionId;

        -----------------------------------------------------------------------------------
        -- 4. Delete every generated document. One statement per type.
        --
        --    Safe as set-based deletes even though both triggers are INSTEAD OF DELETE:
        --    TRG_Delete_VendorPmtTx and TRG_Delete_TFTx each load `deleted` into a table
        --    variable and loop, so they handle multiple rows correctly. Verified by reading
        --    them - do NOT assume this of other INSTEAD OF triggers in this database.
        --
        --    2026-08-06: the TransferFund delete is the ENTIRE deposit unwind - the trigger
        --    resets CustomerPayment.IsLocked, deletes the 'Deposit' journal, and the FK
        --    cascade removes TransferFundDetail (see header).
        -----------------------------------------------------------------------------------
        DELETE FROM dbo.VendorPayment
        WHERE VendorPaymentId IN (SELECT SourceDocId FROM #Sources
                                  WHERE SourceDocType = 'VendorPayment');

        IF EXISTS (SELECT 1 FROM #Sources AS s
                   JOIN dbo.VendorPayment AS vp ON vp.VendorPaymentId = s.SourceDocId
                   WHERE s.SourceDocType = 'VendorPayment')
            THROW 50308, 'A generated vendor payment could not be removed.', 1;

        DELETE FROM dbo.TransferFund
        WHERE TFId IN (SELECT SourceDocId FROM #Sources
                       WHERE SourceDocType = 'Deposit');

        IF EXISTS (SELECT 1 FROM #Sources AS s
                   JOIN dbo.TransferFund AS tf ON tf.TFId = s.SourceDocId
                   WHERE s.SourceDocType = 'Deposit')
            THROW 50314, 'The generated deposit could not be removed.', 1;

        DELETE FROM dbo.TransferFund
        WHERE TFId IN (SELECT SourceDocId FROM #Sources
                       WHERE SourceDocType = 'Transfer');

        IF EXISTS (SELECT 1 FROM #Sources AS s
                   JOIN dbo.TransferFund AS tf ON tf.TFId = s.SourceDocId
                   WHERE s.SourceDocType = 'Transfer')
            THROW 50321, 'The generated transfer could not be removed.', 1;

        -- 2026-08-06 (2b): now that the TransferFund is gone and the cascade has cleared
        -- TransferFundDetail, delete the generated payment(s). TRG_Delete_CustomerPaymentTx
        -- restores the Sales balances and removes the payment journal.
        -- 2026-08-20 RuleMoneyIn: the same delete removes the Other Incoming Payment
        -- journal created by IncomingPayment_Insert.
        DELETE FROM dbo.CustomerPayment
        WHERE CustomerPaymentId IN (SELECT CustomerPaymentId FROM #GeneratedPayments);

        IF EXISTS (SELECT 1 FROM dbo.CustomerPayment AS cp
                   JOIN #GeneratedPayments AS gp ON gp.CustomerPaymentId = cp.CustomerPaymentId)
            THROW 50316, 'The generated customer payment could not be removed.', 1;

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
        WHERE VendorPaymentId IN (SELECT SourceDocId FROM #Sources
                                  WHERE SourceDocType = 'VendorPayment');

        -- 2026-08-06: the Deposit analogue. Opening a deposit in edit mode seeds
        -- TempTransferFund rows stamped with that TFId (Deposit_Inject); once the deposit is
        -- gone they describe a document that no longer exists. TFId > 0 by construction here,
        -- so genuine new-deposit staging (TFId = 0) is never touched.
        DELETE FROM dbo.TempTransferFund
        WHERE TFId IN (SELECT SourceDocId FROM #Sources
                       WHERE SourceDocType = 'Deposit');

        -- 2026-08-06 (2b): and the payment analogue. Opening a payment on the Customer
        -- Payment screen stamps TempCustomerPayment rows with its CustomerPaymentId; once
        -- the generated payment is gone those drafts describe nothing. CustomerPaymentId is
        -- IDENTITY and never reused, and genuine new-payment staging carries 0.
        DELETE FROM dbo.TempCustomerPayment
        WHERE CustomerPaymentId IN (SELECT CustomerPaymentId FROM #GeneratedPayments);

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
