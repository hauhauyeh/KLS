SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- BankFeed_CreateVendorPayment
--   Creates a VendorPayment from a pending money-out bank feed row, applies it to the selected
--   open bills, posts the journal, registers what was generated, and matches the bank row.
--   Plan: plan/bank-feed-create-phase-1-open-bill.md  (Slice 3, decision D6)
--
-- 2026-07-28 FIX_ORPHAN_DRAFT: guard 50113 now ignores a draft whose VendorPaymentId points at
--   a payment that no longer exists. Nothing in the system purges TempVendorPayment, so deleting
--   a payment ANYWHERE - the Vendor Payments screen, or this feature's own reverse - stranded an
--   IsApplied=1 row for a document the user can no longer open, and the guard then refused every
--   subsequent create for that vendor. BankFeed_ReverseVendorPayment now clears its own draft
--   (2026-07-28 version, step 7); this change covers the delete paths outside the feature.
--   No other logic changed; the previous version is
--   KLS/SQL/2026-07-27/BankFeed_CreateVendorPayment.sql.
--
-- One procedure owns the whole flow so there is ONE transaction boundary and ONE error path.
-- The C# service does no orchestration - it serialises the lines to JSON and calls this once.
--
-- Steps: validate -> seed TempVendorPayment -> VendorPayment_Insert -> locate journal ->
--        insert BankFeedSource -> BankFeed_MatchTx.
--
-- Not accepted as parameters, by design:
--   @PaymentDate           - always the bank row's PostedDate (D3)
--   @DifferenceResolution  - derived here from the amounts (D9)
--   @Notes                 - built from the bank description
--   @DifferenceAccountId   - VendorPayment_Insert hardcodes discounts to '@IDR' (D1)
--
-- Error numbers 50101-50118. BankFeed_MatchTx owns 50001-50008; BankFeed_GetOpenBills 50201+.
-- =============================================================================================

CREATE OR ALTER PROCEDURE [dbo].[BankFeed_CreateVendorPayment]
    @BankFeedTransactionId BIGINT,
    @PayeeId               INT,
    @PaymentMethod         NVARCHAR(50),
    @ReferenceId           NVARCHAR(100) = NULL,
    @LinesJson             NVARCHAR(MAX),
    @DifferenceMemo        NVARCHAR(500) = NULL,
    @EmpId                 INT,
    @NewVendorPaymentId    INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ---------------------------------------------------------------------------------------
    -- A. Parse the lines. Touches no database state, so it sits outside the transaction.
    ---------------------------------------------------------------------------------------
    IF @LinesJson IS NULL OR ISJSON(@LinesJson) <> 1
        THROW 50107, 'No bills were selected for this payment.', 1;

    SELECT PurchaseId,
           ApplyAmount,
           ISNULL(DiscountAmount, 0) AS DiscountAmount
    INTO #Lines
    FROM OPENJSON(@LinesJson)
    WITH (PurchaseId     INT,
          ApplyAmount    DECIMAL(18,2),
          DiscountAmount DECIMAL(18,2));

    IF NOT EXISTS (SELECT 1 FROM #Lines)
        THROW 50107, 'No bills were selected for this payment.', 1;

    ---------------------------------------------------------------------------------------
    -- The transaction opens BEFORE validation on purpose.
    -- The UPDLOCK on BankFeedTransaction below only holds for the life of a transaction.
    -- Without it two users clicking Create on the same bank row would both pass the
    -- "no Active BankFeedSource" check and both create a payment: BankFeed_MatchTx does not
    -- reject an already-Matched row, so the second would happily attach a second payment.
    -- Validation still runs before any write, so a THROW here rolls back nothing.
    ---------------------------------------------------------------------------------------
    BEGIN TRAN;
    BEGIN TRY

        -----------------------------------------------------------------------------------
        -- B. Load the bank feed row and the GL account it maps to
        -----------------------------------------------------------------------------------
        DECLARE @Status         VARCHAR(20),
                @PostedDate     DATE,
                @BankAmount     DECIMAL(18,2),
                @Description    NVARCHAR(500),
                @BankAccountId  INT,
                @IsAccountDebit BIT;

        SELECT @Status         = bft.[Status],
               @PostedDate     = bft.PostedDate,
               @BankAmount     = bft.Amount,
               @Description    = bft.[Description],
               @BankAccountId  = bfa.AccountId,
               @IsAccountDebit = a.IsAccountDebit
        FROM dbo.BankFeedTransaction AS bft WITH (UPDLOCK, HOLDLOCK)
        LEFT JOIN dbo.BankFeedAccount AS bfa
            ON bfa.BankFeedAccountId = bft.BankFeedAccountId
        LEFT JOIN dbo.Account AS a
            ON a.AccountId = bfa.AccountId
        WHERE bft.BankFeedTransactionId = @BankFeedTransactionId;

        -----------------------------------------------------------------------------------
        -- C. Validate. Everything THROWs; nothing has been written yet.
        -----------------------------------------------------------------------------------
        IF @Status IS NULL
            THROW 50101, 'Bank feed transaction not found.', 1;

        IF @Status <> 'Pending'
            THROW 50102, 'Only pending bank feed transactions can create a payment.', 1;

        IF @BankAmount >= 0
            THROW 50103, 'Only money-out bank feed transactions can pay open bills.', 1;

        IF @BankAccountId IS NULL
            THROW 50104, 'This bank feed row is not mapped to a GL account.', 1;

        -- The bank line posts as -PaymentAmount only for a debit (asset) account. On a credit
        -- account the sign flips and BankFeed_MatchTx would reject the amount with a much less
        -- helpful message, so catch the misconfiguration here.
        IF @IsAccountDebit <> 1
            THROW 50118, 'The GL account mapped to this bank feed is not a debit account.', 1;

        IF EXISTS (SELECT 1 FROM dbo.BankFeedSource
                   WHERE BankFeedTransactionId = @BankFeedTransactionId
                     AND [Status] = 'Active')
            THROW 50105, 'This bank feed row already has a transaction created by Bank Feed. Reverse it first.', 1;

        -- 'CHECK' is excluded: VendorPayment_Insert would call Get_CheckNumber, which
        -- overwrites @ReferenceId and consumes a number from CheckTracker. A bank feed row
        -- already carries its own check number, so both behaviours are wrong here.
        IF @PaymentMethod IS NULL
           OR @PaymentMethod NOT IN ('ACH', 'E-CHECK', 'CASH', 'HANDWRITE CHECK', 'CREDIT CARD')
            THROW 50106, 'Unsupported payment method for a bank feed payment.', 1;

        IF EXISTS (SELECT 1 FROM #Lines
                   WHERE ApplyAmount IS NULL OR ApplyAmount <= 0 OR DiscountAmount < 0)
            THROW 50108, 'Each selected bill needs an apply amount greater than zero.', 1;

        -- Without this, two lines for one bill could each pass the per-line balance check
        -- while together exceeding it - VendorPayment_Insert's own guard is also per-row.
        IF EXISTS (SELECT 1 FROM #Lines GROUP BY PurchaseId HAVING COUNT(*) > 1)
            THROW 50117, 'The same bill was selected more than once.', 1;

        IF EXISTS (SELECT 1
                   FROM #Lines AS l
                   LEFT JOIN dbo.Purchase AS p ON p.PurchaseId = l.PurchaseId
                   WHERE p.PurchaseId IS NULL
                      OR p.StageId <> 6
                      OR p.AmountDue <= 0)
            THROW 50109, 'One or more selected bills are no longer open.', 1;

        IF EXISTS (SELECT 1
                   FROM #Lines AS l
                   JOIN dbo.Purchase AS p ON p.PurchaseId = l.PurchaseId
                   WHERE p.PayeeId <> @PayeeId)
            THROW 50110, 'All selected bills must belong to the same vendor.', 1;

        IF EXISTS (SELECT 1
                   FROM #Lines AS l
                   JOIN dbo.Purchase AS p ON p.PurchaseId = l.PurchaseId
                   WHERE l.ApplyAmount + l.DiscountAmount > p.AmountDue)
            THROW 50111, 'Apply plus discount cannot exceed a bill''s open balance.', 1;

        -- The invariant the journal depends on: the cash side of the payment IS the bank row.
        IF (SELECT SUM(ApplyAmount) FROM #Lines) <> ABS(@BankAmount)
            THROW 50112, 'The applied total must equal the bank amount.', 1;

        -- TempVendorPayment is keyed on (EmpId, PayeeId) only. VendorPayment_Insert reads every
        -- IsApplied=1 row for that key and then deletes them all, so an open manual draft for
        -- the same vendor would be absorbed into this payment and destroyed.
        --
        -- Only IsApplied=1 blocks. The manual payment screen seeds a row per open bill via
        -- VendorPayment_Inject and never cleans them up, so untouched IsApplied=0 rows pile up
        -- from abandoned sessions (98 such rows live at the time of writing). Those carry no
        -- user intent, contribute nothing to the payment, and are re-seeded on next open -
        -- blocking on them would fail the create for stale junk the user never chose.
        --
        -- 2026-07-28: and only a draft for a payment that STILL EXISTS can be harmed.
        -- VendorPayment_Inject stamps injected rows with the VendorPaymentId they came from;
        -- nothing purges them, so deleting a payment strands an IsApplied=1 row pointing at a
        -- document the user can no longer open. That debris is not a draft anyone can "finish
        -- or discard" - it is unreachable from the UI - so blocking on it left the vendor
        -- permanently unusable here. VendorPaymentId = 0 is a genuine new-payment draft and
        -- always blocks.
        IF EXISTS (SELECT 1
                   FROM dbo.TempVendorPayment AS t
                   WHERE t.EmpId     = @EmpId
                     AND t.PayeeId   = @PayeeId
                     AND t.IsApplied = 1
                     AND (t.VendorPaymentId = 0
                          OR EXISTS (SELECT 1 FROM dbo.VendorPayment AS vp
                                     WHERE vp.VendorPaymentId = t.VendorPaymentId)))
            THROW 50113, 'You have an unsaved vendor payment draft for this vendor. Finish or discard it first.', 1;

        IF EXISTS (SELECT 1 FROM #Lines WHERE DiscountAmount > 0)
           AND (@DifferenceMemo IS NULL OR LTRIM(RTRIM(@DifferenceMemo)) = '')
            THROW 50116, 'A memo is required when a discount is applied.', 1;

        -----------------------------------------------------------------------------------
        -- C2. Capture the totals NOW, while Purchase.AmountDue is still pre-payment.
        --     VendorPayment_Insert calls VendorPayment_UpdatePurchase, which rewrites
        --     AmountDue for every bill it touches. Reading these after step E would give
        --     post-payment balances and store a negative DifferenceAmount in every case.
        -----------------------------------------------------------------------------------
        DECLARE @AppliedTotal         DECIMAL(18,2),
                @DiscountTotal        DECIMAL(18,2),
                @SelectedOpenTotal    DECIMAL(18,2),
                @DifferenceAmount     DECIMAL(18,2),
                @DifferenceResolution VARCHAR(50);

        SELECT @AppliedTotal      = SUM(l.ApplyAmount),
               @DiscountTotal     = SUM(l.DiscountAmount),
               @SelectedOpenTotal = SUM(p.AmountDue)
        FROM #Lines AS l
        JOIN dbo.Purchase AS p ON p.PurchaseId = l.PurchaseId;

        SET @DifferenceAmount = @SelectedOpenTotal - @AppliedTotal;

        SET @DifferenceResolution =
            CASE WHEN @DifferenceAmount  = 0                THEN 'None'
                 WHEN @DiscountTotal     = 0                THEN 'Partial'
                 WHEN @DiscountTotal     = @DifferenceAmount THEN 'Discount'
                 ELSE 'Mixed'
            END;

        -----------------------------------------------------------------------------------
        -- D. Seed the staging table VendorPayment_Insert reads from
        -----------------------------------------------------------------------------------
        INSERT INTO dbo.TempVendorPayment
            (EmpId, PayeeId, VendorPaymentId, PurchaseId, AmountDue,
             PaymentApplied, DiscountApplied, IsApplied)
        SELECT @EmpId, @PayeeId, 0, l.PurchaseId, p.AmountDue,
               l.ApplyAmount, l.DiscountAmount, 1
        FROM #Lines AS l
        JOIN dbo.Purchase AS p ON p.PurchaseId = l.PurchaseId;

        -----------------------------------------------------------------------------------
        -- E. Create the payment, apply it, and post the journal.
        --    @PaymentType is passed but VendorPayment_Insert overwrites it from
        --    @PaymentMethod - that is why step F reads the stored value back.
        --    The procedure deletes the TempVendorPayment rows itself on success.
        -----------------------------------------------------------------------------------
        DECLARE @Notes NVARCHAR(255) = LEFT(N'Bank feed: ' + ISNULL(@Description, N''), 255);

        EXEC dbo.VendorPayment_Insert
            @VendorPaymentId = 0,
            @PayeeId         = @PayeeId,
            @PaymentDate     = @PostedDate,
            @PaymentType     = N'Bill Payment',
            @PaymentMethod   = @PaymentMethod,
            @ReferenceId     = @ReferenceId,
            @FromAccountId   = @BankAccountId,
            @PaymentAmount   = @AppliedTotal,
            @Notes           = @Notes,
            @EmpId           = @EmpId,
            @NewPaymentId    = @NewVendorPaymentId OUTPUT;

        IF @NewVendorPaymentId IS NULL OR @NewVendorPaymentId <= 0
            THROW 50119, 'The vendor payment could not be created.', 1;

        -----------------------------------------------------------------------------------
        -- F. Locate the journal it posted. VendorPayment_Insert returns no TxId, so the
        --    handle is (SourceDocType, SourceDocNumber) - exactly what TRG_Delete_VendorPmtTx
        --    uses to delete it. Assert a single row rather than taking TOP 1: this is money,
        --    and if the assumption ever breaks it should stop rather than guess.
        -----------------------------------------------------------------------------------
        DECLARE @PaymentNumber  INT,
                @NewPaymentType NVARCHAR(100),
                @TxId           BIGINT,
                @TxDetailId     BIGINT,
                @RowCheck       INT;

        SELECT @PaymentNumber  = PaymentNumber,
               @NewPaymentType = PaymentType
        FROM dbo.VendorPayment
        WHERE VendorPaymentId = @NewVendorPaymentId;

        SELECT @RowCheck = COUNT(*), @TxId = MIN(TxId)
        FROM dbo.TransactionJournal
        WHERE SourceDocType   = @NewPaymentType
          AND SourceDocNumber = @PaymentNumber;

        IF @RowCheck <> 1
            THROW 50114, 'Could not identify the journal transaction for the new payment.', 1;

        SELECT @RowCheck = COUNT(*), @TxDetailId = MIN(TxDetailId)
        FROM dbo.TransactionJournalDetail
        WHERE TxId = @TxId
          AND AccountId = @BankAccountId;

        IF @RowCheck <> 1
            THROW 50115, 'Could not identify the bank line of the new journal transaction.', 1;

        -----------------------------------------------------------------------------------
        -- G. Register what Bank Feed generated, so it can be traced and reversed.
        --    OriginalBankAmount keeps the SIGNED bank amount (negative for money out);
        --    AppliedAmount and DifferenceAmount are positive.
        -----------------------------------------------------------------------------------
        INSERT INTO dbo.BankFeedSource
            (BankFeedTransactionId, SourceDocType, SourceDocId, TxId,
             [Mode], [Status], OriginalBankAmount, AppliedAmount, DifferenceAmount,
             DifferenceResolution, DifferenceMemo, CreatedAt, CreatedBy)
        VALUES
            (@BankFeedTransactionId, 'VendorPayment', @NewVendorPaymentId, @TxId,
             'PayOpenBill', 'Active', @BankAmount, @AppliedTotal, @DifferenceAmount,
             @DifferenceResolution, @DifferenceMemo, SYSUTCDATETIME(), @EmpId);

        -----------------------------------------------------------------------------------
        -- H. Match through the existing path, so create and manual match cannot drift.
        --    It re-validates account / amount / not-already-matched / not-locked, sets the
        --    journal BankDate (VendorPayment_Insert leaves it NULL on new payments), and
        --    moves the header to Matched.
        -----------------------------------------------------------------------------------
        DECLARE @MatchItemsJson NVARCHAR(MAX) =
            (SELECT @TxId AS TxId, @TxDetailId AS TxDetailId FOR JSON PATH);

        EXEC dbo.BankFeed_MatchTx
            @BankFeedTransactionId = @BankFeedTransactionId,
            @MatchItemsJson        = @MatchItemsJson,
            @MatchedBy             = @EmpId;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        -- BankFeed_MatchTx rolls back on its own failure, which ends this transaction too.
        -- The @@TRANCOUNT guard is what stops a second rollback attempt here. Do not remove it.
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
