
-- =============================================================================================
-- BankFeed_CreateVendorPayment
--   Creates a VendorPayment from a pending money-out bank feed row, applies it to the selected
--   open bills, posts the journal, registers what was generated, and matches the bank row.
--   Plan: plan/bank-feed-create-phase-1-open-bill.md  (Slice 3, decision D6)
--
-- 2026-08-12 per-line vendor (plan/plan-bankfeed-resolve-per-line-vendor-v1.md, Slice 1):
--   Each resolving line now carries its OWN vendor instead of one @ChargePayeeId for all of
--   them. @ChargePayeeId is removed from the signature; the resolving JSON gains PayeeId.
--   Step F2 becomes a cursor over the distinct resolving vendors - one PayNow per vendor,
--   each with its own BankFeedSource 'ResolveDifference' row - mirroring the step D-G vendor
--   cursor. Freed error numbers 50140/50141 are reused for the per-line vendor checks, and
--   the TempPurchase draft guard 50137 now covers every resolving vendor.
--   BankFeed_ReverseGenerated already reverses every Active source row set-based - no change.
--
-- 2026-08-11 multi-vendor (plan/bank-feed-create-phase-5-multi-vendor.md, Slice 2, D1/D2):
--   The selected bills may now span several vendors. The vendor set is derived from the
--   bills themselves, so @PayeeId is REMOVED from the signature and guard 50110 is retired.
--   One VendorPayment is created PER VENDOR (QuickBooks parity - a payment document is
--   always one vendor), each with its own BankFeedSource row and its own difference
--   resolution computed from its own bills; the single bank row then matches ALL the bank
--   lines in one BankFeed_MatchTx call, whose sum check is unchanged. Multiple Active
--   BankFeedSource rows per bank row is the 4b precedent (payment + charge), generalised.
--   BankFeed_ReverseGenerated already reverses every Active source set-based - no change.
--   A selection spanning more than 10 vendors is refused (50142): each vendor is a full
--   VendorPayment_Insert round trip inside one transaction, and a real combined debit runs
--   2-5 vendors.
--
-- 2026-07-29 KLS-4B: resolving lines. The bank amount may now exceed the bills being paid, with
--   the gap absorbed by expense lines the user chooses - a wire fee, a bank charge. Until now
--   that case could not be entered at all: 50112 demanded the applied total equal the bank
--   amount while 50111 capped it at the bills' open balance, and both cannot hold at once.
--
--   The gap becomes a SECOND document, created through VendorPayment_InsertPayNow (the existing
--   expense module). Both documents post a line on the bank account, and BankFeed_MatchTx
--   already requires the SUM of matched detail lines to equal the bank amount - so the
--   invariant is not relaxed, it gains a second term.
--
--   Plan: plan/bank-feed-create-phase-4b-resolving-lines.md
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
-- Steps: validate -> PER VENDOR (seed TempVendorPayment -> VendorPayment_Insert -> locate
--        journal -> insert BankFeedSource) -> optional charge -> BankFeed_MatchTx once.
--
-- Not accepted as parameters, by design:
--   @PaymentDate           - always the bank row's PostedDate (D3)
--   @DifferenceResolution  - derived here from the amounts (D9)
--   @Notes                 - built from the bank description
--   @DifferenceAccountId   - VendorPayment_Insert hardcodes discounts to '@IDR' (D1)
--   @PayeeId               - since 2026-08-11 the vendor set comes from the bills
--
-- Error numbers 50101-50119, 50130-50141 and 50142. BankFeed_MatchTx owns 50001-50008;
--   BankFeed_GetOpenBills 50201+; BankFeed_ReverseGenerated 50301+.
--   50120-50123 are reserved for a shelved phase (4a) and deliberately skipped.
--   Note Shipment_GenerateChargeBills also throws 50101-50108. That collision is pre-existing
--   and harmless - nothing branches on the number - so do not renumber either procedure.
-- =============================================================================================

CREATE   PROCEDURE [dbo].[BankFeed_CreateVendorPayment]
    -- EXEC dbo.BankFeed_CreateVendorPayment @BankFeedTransactionId=1, @PaymentMethod='ACH',
    --      @LinesJson='[{"PurchaseId":1,"ApplyAmount":10.00,"DiscountAmount":0}]',
    --      @ResolvingLinesJson='[{"PayeeId":100002,"AccountId":133,"Amount":10.00,"Notes":"wire fee"}]',
    --      @EmpId=100001, @NewVendorPaymentId=NULL
    @BankFeedTransactionId BIGINT,
    -- 2026-08-11 multi-vendor: @PayeeId removed - the vendor set is derived from the bills.
    @PaymentMethod         NVARCHAR(50),
    @ReferenceId           NVARCHAR(100) = NULL,
    @LinesJson             NVARCHAR(MAX),
    @DifferenceMemo        NVARCHAR(500) = NULL,
    -- 2026-07-29 KLS-4B. Since 2026-08-12 each line carries its own vendor:
    -- [{"PayeeId":100002,"AccountId":133,"Amount":10.00,"Notes":"wire fee"}]
    -- NULL or empty = no resolving lines, and this procedure behaves exactly as it did before.
    @ResolvingLinesJson    NVARCHAR(MAX) = NULL,
    -- 2026-08-12 per-line vendor: @ChargePayeeId removed - each resolving line names its vendor.
    --@ChargePayeeId         INT           = NULL,
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

    -- 2026-07-29 KLS-4B. Absent or empty is the ordinary case and leaves everything below
    -- behaving exactly as it did before this parameter existed.
    CREATE TABLE #Resolving
    (
        -- 2026-08-12 per-line vendor: PayeeId added - each line names the vendor its charge
        -- document is billed to.
        PayeeId   INT            NULL,
        AccountId INT            NULL,
        Amount    DECIMAL(18,2)  NULL,
        Notes     NVARCHAR(255)  NULL
    );

    IF @ResolvingLinesJson IS NOT NULL AND LTRIM(RTRIM(@ResolvingLinesJson)) <> ''
    BEGIN
        IF ISJSON(@ResolvingLinesJson) <> 1
            THROW 50130, 'The resolving lines are not valid.', 1;

        INSERT INTO #Resolving (PayeeId, AccountId, Amount, Notes)
        SELECT PayeeId, AccountId, Amount, Notes
        FROM OPENJSON(@ResolvingLinesJson)
        WITH (PayeeId INT, AccountId INT, Amount DECIMAL(18,2), Notes NVARCHAR(255));
    END

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

        -- 2026-08-11 multi-vendor: guard retired - bills may now span vendors (D1/D2).
        --IF EXISTS (SELECT 1
        --           FROM #Lines AS l
        --           JOIN dbo.Purchase AS p ON p.PurchaseId = l.PurchaseId
        --           WHERE p.PayeeId <> @PayeeId)
        --    THROW 50110, 'All selected bills must belong to the same vendor.', 1;

        -- 2026-08-11 multi-vendor: the vendor set this create will loop over. Derived after
        -- 50109 so every bill is known to exist. Capped because each vendor is a full
        -- VendorPayment_Insert round trip inside this one transaction.
        SELECT DISTINCT p.PayeeId
        INTO #Vendors
        FROM #Lines AS l
        JOIN dbo.Purchase AS p ON p.PurchaseId = l.PurchaseId;

        IF (SELECT COUNT(*) FROM #Vendors) > 10
            THROW 50142, 'A bank feed row can pay bills of at most 10 vendors at once.', 1;

        IF EXISTS (SELECT 1
                   FROM #Lines AS l
                   JOIN dbo.Purchase AS p ON p.PurchaseId = l.PurchaseId
                   WHERE l.ApplyAmount + l.DiscountAmount > p.AmountDue)
            THROW 50111, 'Apply plus discount cannot exceed a bill''s open balance.', 1;

        -----------------------------------------------------------------------------------
        -- C1. Resolving lines (2026-07-29 KLS-4B).
        --     With none supplied, #Resolving is empty, @ResolvingTotal is 0, and the invariant
        --     below reduces to exactly the pre-4B check.
        -----------------------------------------------------------------------------------
        DECLARE @ResolvingTotal DECIMAL(18,2) =
            ISNULL((SELECT SUM(Amount) FROM #Resolving), 0);

        IF EXISTS (SELECT 1 FROM #Resolving)
        BEGIN
            IF EXISTS (SELECT 1 FROM #Resolving WHERE Amount IS NULL OR Amount <= 0)
                THROW 50131, 'Each resolving line needs an amount greater than zero.', 1;

            IF (SELECT COUNT(*) FROM #Resolving) > 5
                THROW 50134, 'A bank feed row can carry at most 5 resolving lines.', 1;

            IF EXISTS (SELECT 1 FROM #Resolving AS r
                       WHERE NOT EXISTS (SELECT 1 FROM dbo.Account AS a
                                         WHERE a.AccountId = r.AccountId))
                THROW 50132, 'One or more resolving lines use an account that does not exist.', 1;

            -- Posting a resolving line to the bank account would net against the bank line and
            -- vanish; posting it to AP would double-count what the payment side already owns.
            IF EXISTS (SELECT 1 FROM #Resolving WHERE AccountId = @BankAccountId)
                THROW 50133, 'A resolving line cannot post to the bank account of this bank feed row.', 1;

            IF EXISTS (SELECT 1 FROM #Resolving AS r
                       JOIN dbo.Account AS a ON a.AccountId = r.AccountId
                       WHERE a.AccountCode = '@AP')
                THROW 50135, 'A resolving line cannot post to Accounts Payable.', 1;

            -- 2026-08-12 per-line vendor: 50140/50141 keep their numbers (freed by retiring
            -- @ChargePayeeId) but now check every line's own vendor.
            --IF @ChargePayeeId IS NULL
            --    THROW 50140, 'Please choose who the bank charge is billed to.', 1;
            --
            --IF NOT EXISTS (SELECT 1 FROM dbo.Payee WHERE PayeeId = @ChargePayeeId)
            --    THROW 50141, 'The selected charge payee does not exist.', 1;
            IF EXISTS (SELECT 1 FROM #Resolving WHERE PayeeId IS NULL)
                THROW 50140, 'Each resolving line needs a vendor.', 1;

            IF EXISTS (SELECT 1 FROM #Resolving AS r
                       WHERE NOT EXISTS (SELECT 1 FROM dbo.Payee AS p
                                         WHERE p.PayeeId = r.PayeeId))
                THROW 50141, 'One or more resolving lines use a vendor that does not exist.', 1;

            -- TempPurchase is keyed on (EmpId, PayeeId). VendorPayment_InsertPayNow reads the
            -- rows for that key and then DELETEs them WITHOUT a PurchaseId filter, so an
            -- in-progress purchase edit for the same payee would be destroyed without even
            -- being absorbed. Same shape as guard 50113, and strictly worse.
            -- 2026-08-12 per-line vendor: checked across EVERY resolving vendor (was the one
            -- @ChargePayeeId) - all-or-nothing, before any write.
            IF EXISTS (SELECT 1 FROM dbo.TempPurchase AS t
                       WHERE t.EmpId = @EmpId
                         AND t.PayeeId IN (SELECT r.PayeeId FROM #Resolving AS r))
                THROW 50137, 'You have an unsaved purchase or expense draft for a resolving line vendor. Finish or discard it first.', 1;
        END

        -- The invariant the journal depends on: the cash side of everything created here IS the
        -- bank row. BankFeed_MatchTx re-checks the same sum against the journal (step H), which
        -- is the second line of defence behind this.
        IF (SELECT SUM(ApplyAmount) FROM #Lines) + @ResolvingTotal <> ABS(@BankAmount)
            THROW 50112, 'The applied total plus any resolving lines must equal the bank amount.', 1;

        -- The bank moved LESS than was applied to bills, which means something else funded the
        -- difference - a vendor credit or an advance. Posting a plausible-looking journal for
        -- the wrong reason is worse than refusing.
        IF ABS(@BankAmount) - (SELECT SUM(ApplyAmount) FROM #Lines) < 0
            THROW 50136, 'The bills applied exceed the bank amount. Vendor credits are not supported here.', 1;

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
        --
        -- 2026-08-11 multi-vendor: checked across EVERY involved vendor (was one @PayeeId) -
        -- all-or-nothing, before any write, so no payment is created and then orphaned by a
        -- later vendor's refusal.
        IF EXISTS (SELECT 1
                   FROM dbo.TempVendorPayment AS t
                   WHERE t.EmpId     = @EmpId
                     AND t.PayeeId   IN (SELECT v.PayeeId FROM #Vendors AS v)
                     AND t.IsApplied = 1
                     AND (t.VendorPaymentId = 0
                          OR EXISTS (SELECT 1 FROM dbo.VendorPayment AS vp
                                     WHERE vp.VendorPaymentId = t.VendorPaymentId)))
            THROW 50113, 'You have an unsaved vendor payment draft for one of the selected vendors. Finish or discard it first.', 1;

        IF EXISTS (SELECT 1 FROM #Lines WHERE DiscountAmount > 0)
           AND (@DifferenceMemo IS NULL OR LTRIM(RTRIM(@DifferenceMemo)) = '')
            THROW 50116, 'A memo is required when a discount is applied.', 1;

        -----------------------------------------------------------------------------------
        -- C2. Capture the totals NOW, while Purchase.AmountDue is still pre-payment.
        --     VendorPayment_Insert calls VendorPayment_UpdatePurchase, which rewrites
        --     AmountDue for every bill it touches. Reading these after step E would give
        --     post-payment balances and store a negative DifferenceAmount in every case.
        --
        --     2026-08-11 multi-vendor: per VENDOR GROUP instead of one scalar set - each
        --     payment carries its own applied total and its own difference resolution,
        --     derived from its own bills only (D4).
        -----------------------------------------------------------------------------------
        SELECT p.PayeeId,
               SUM(l.ApplyAmount)    AS AppliedTotal,
               SUM(l.DiscountAmount) AS DiscountTotal,
               SUM(p.AmountDue)      AS SelectedOpenTotal,
               CAST(SUM(p.AmountDue) - SUM(l.ApplyAmount) AS DECIMAL(18,2)) AS DifferenceAmount,
               CAST(CASE WHEN SUM(p.AmountDue) - SUM(l.ApplyAmount) = 0 THEN 'None'
                         WHEN SUM(l.DiscountAmount) = 0                 THEN 'Partial'
                         WHEN SUM(l.DiscountAmount) =
                              SUM(p.AmountDue) - SUM(l.ApplyAmount)     THEN 'Discount'
                         ELSE 'Mixed'
                    END AS VARCHAR(50)) AS DifferenceResolution
        INTO #Groups
        FROM #Lines AS l
        JOIN dbo.Purchase AS p ON p.PurchaseId = l.PurchaseId
        GROUP BY p.PayeeId;

        -----------------------------------------------------------------------------------
        -- D-G. One payment per vendor group (2026-08-11 multi-vendor, D1/D9).
        --      Deterministic order (PayeeId), scalar vars reset every iteration. Each pass:
        --      seed the staging rows for THIS vendor only -> VendorPayment_Insert (which
        --      consumes and deletes exactly those rows) -> locate the journal it posted ->
        --      register the BankFeedSource row -> collect the bank line for the match.
        -----------------------------------------------------------------------------------
        DECLARE @Notes NVARCHAR(255) = LEFT(N'Bank feed: ' + ISNULL(@Description, N''), 255);

        DECLARE @MatchItems TABLE (TxId BIGINT NOT NULL, TxDetailId BIGINT NOT NULL);

        DECLARE @GroupPayeeId    INT,
                @GroupApplied    DECIMAL(18,2),
                @GroupDifference DECIMAL(18,2),
                @GroupResolution VARCHAR(50),
                @GroupPaymentId  INT,
                @PaymentNumber   INT,
                @NewPaymentType  NVARCHAR(100),
                @TxId            BIGINT,
                @TxDetailId      BIGINT,
                @RowCheck        INT;

        SET @NewVendorPaymentId = NULL;

        DECLARE vendor_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT PayeeId, AppliedTotal, DifferenceAmount, DifferenceResolution
            FROM #Groups
            ORDER BY PayeeId;

        OPEN vendor_cursor;
        FETCH NEXT FROM vendor_cursor
        INTO @GroupPayeeId, @GroupApplied, @GroupDifference, @GroupResolution;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Reset per-iteration state (project WHILE-loop law): a stale value from the
            -- previous vendor must never leak into this one.
            SET @GroupPaymentId = NULL;
            SET @PaymentNumber  = NULL;
            SET @NewPaymentType = NULL;
            SET @TxId           = NULL;
            SET @TxDetailId     = NULL;
            SET @RowCheck       = NULL;

            -------------------------------------------------------------------------------
            -- D. Seed the staging table VendorPayment_Insert reads from - THIS vendor only.
            --    AmountDue is still pre-payment for this vendor: earlier iterations only
            --    touched their own vendors' bills.
            -------------------------------------------------------------------------------
            INSERT INTO dbo.TempVendorPayment
                (EmpId, PayeeId, VendorPaymentId, PurchaseId, AmountDue,
                 PaymentApplied, DiscountApplied, IsApplied)
            SELECT @EmpId, @GroupPayeeId, 0, l.PurchaseId, p.AmountDue,
                   l.ApplyAmount, l.DiscountAmount, 1
            FROM #Lines AS l
            JOIN dbo.Purchase AS p ON p.PurchaseId = l.PurchaseId
            WHERE p.PayeeId = @GroupPayeeId;

            -------------------------------------------------------------------------------
            -- E. Create the payment, apply it, and post the journal.
            --    @PaymentType is passed but VendorPayment_Insert overwrites it from
            --    @PaymentMethod - that is why step F reads the stored value back.
            --    The procedure deletes the TempVendorPayment rows itself on success.
            -------------------------------------------------------------------------------
            EXEC dbo.VendorPayment_Insert
                @VendorPaymentId = 0,
                @PayeeId         = @GroupPayeeId,
                @PaymentDate     = @PostedDate,
                @PaymentType     = N'Bill Payment',
                @PaymentMethod   = @PaymentMethod,
                @ReferenceId     = @ReferenceId,
                @FromAccountId   = @BankAccountId,
                @PaymentAmount   = @GroupApplied,
                @Notes           = @Notes,
                @EmpId           = @EmpId,
                @NewPaymentId    = @GroupPaymentId OUTPUT;

            IF @GroupPaymentId IS NULL OR @GroupPaymentId <= 0
                THROW 50119, 'The vendor payment could not be created.', 1;

            -------------------------------------------------------------------------------
            -- F. Locate the journal it posted. VendorPayment_Insert returns no TxId, so the
            --    handle is (SourceDocType, SourceDocNumber) - exactly what
            --    TRG_Delete_VendorPmtTx uses to delete it. Assert a single row rather than
            --    taking TOP 1: this is money, and if the assumption ever breaks it should
            --    stop rather than guess.
            -------------------------------------------------------------------------------
            SELECT @PaymentNumber  = PaymentNumber,
                   @NewPaymentType = PaymentType
            FROM dbo.VendorPayment
            WHERE VendorPaymentId = @GroupPaymentId;

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

            -------------------------------------------------------------------------------
            -- G. Register what Bank Feed generated, so it can be traced and reversed.
            --    OriginalBankAmount keeps the SIGNED bank amount (negative for money out);
            --    AppliedAmount and DifferenceAmount are positive and are THIS payment's own
            --    numbers (D4). One row per generated payment - the 4b two-row precedent,
            --    generalised. BankFeed_ReverseGenerated reverses every Active row set-based.
            -------------------------------------------------------------------------------
            INSERT INTO dbo.BankFeedSource
                (BankFeedTransactionId, SourceDocType, SourceDocId, TxId,
                 [Mode], [Status], OriginalBankAmount, AppliedAmount, DifferenceAmount,
                 DifferenceResolution, DifferenceMemo, CreatedAt, CreatedBy)
            VALUES
                (@BankFeedTransactionId, 'VendorPayment', @GroupPaymentId, @TxId,
                 'PayOpenBill', 'Active', @BankAmount, @GroupApplied, @GroupDifference,
                 @GroupResolution, @DifferenceMemo, SYSUTCDATETIME(), @EmpId);

            INSERT INTO @MatchItems (TxId, TxDetailId) VALUES (@TxId, @TxDetailId);

            -- The OUTPUT keeps its single-payment contract: the first created payment
            -- (lowest PayeeId). The caller only uses it as a success signal.
            IF @NewVendorPaymentId IS NULL
                SET @NewVendorPaymentId = @GroupPaymentId;

            FETCH NEXT FROM vendor_cursor
            INTO @GroupPayeeId, @GroupApplied, @GroupDifference, @GroupResolution;
        END

        CLOSE vendor_cursor;
        DEALLOCATE vendor_cursor;

        -----------------------------------------------------------------------------------
        -- F2. The charge documents (2026-07-29 KLS-4B). Skipped entirely when there are no
        --     resolving lines.
        --
        --     PayNow is used rather than a General Journal because a PayNow IS a
        --     VendorPayment: SourceDocType stays 'VendorPayment' below, so every Phase 1
        --     guard keeps working unedited, and TRG_Delete_VendorPmtTx already deletes the
        --     Purchase a PayNow generates - so reversal needs no new code either.
        --
        --     2026-08-12 per-line vendor: one PayNow PER DISTINCT resolving vendor instead of
        --     one for a single @ChargePayeeId - the same cursor shape as step D-G. Lines on
        --     the same vendor stay grouped into one charge document, exactly as all lines did
        --     before. VendorPayment_InsertPayNow reads and deletes TempPurchase scoped to
        --     (EmpId, PayeeId), so each iteration consumes only its own vendor's rows.
        -----------------------------------------------------------------------------------
        DECLARE @ChargePaymentId INT           = NULL,
                @ChargeTxId      BIGINT        = NULL,
                @ChargeTxDetail  BIGINT        = NULL,
                @ChargeMethod    NVARCHAR(50),
                @ChargeNumber    INT,
                @ChargeType      NVARCHAR(100),
                -- 2026-08-12 per-line vendor: this iteration's vendor and its own total.
                @ChargePayeeId   INT,
                @ChargeVendorTotal DECIMAL(18,2);

        IF EXISTS (SELECT 1 FROM #Resolving)
        BEGIN
            -- 'CHECK' would make VendorPayment_InsertPayNow call Get_CheckNumber, consuming a
            -- CheckTracker number for something that is not a cheque. 50106 already blocks it
            -- on the payment side; this is belt and braces for a value that cannot arrive.
            SET @ChargeMethod = CASE WHEN @PaymentMethod = 'CHECK' THEN 'ACH' ELSE @PaymentMethod END;

            DECLARE charge_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT PayeeId, SUM(Amount)
                FROM #Resolving
                GROUP BY PayeeId
                ORDER BY PayeeId;

            OPEN charge_cursor;
            FETCH NEXT FROM charge_cursor INTO @ChargePayeeId, @ChargeVendorTotal;

            WHILE @@FETCH_STATUS = 0
            BEGIN
            -- Reset per-iteration state (project WHILE-loop law): a stale value from the
            -- previous vendor must never leak into this one.
            SET @ChargePaymentId = NULL;
            SET @ChargeTxId      = NULL;
            SET @ChargeTxDetail  = NULL;
            SET @ChargeNumber    = NULL;
            SET @ChargeType      = NULL;
            SET @RowCheck        = NULL;

            -- One row per resolving line of THIS vendor, all LineType 'A' (account lines).
            --
            -- The Bill* columns are not optional padding: VendorPayment_InsertPayNow rebuilds
            -- the header from the detail rows, taking VendorTotal from SUM(BillQty * BillPrice)
            -- and PurchaseTotal from SUM(FinalQty * FinalPrice) - two separate sums. Seeding
            -- only the Final* columns yields VendorTotal 0 against a real PurchaseTotal, i.e. a
            -- bill claiming the vendor billed nothing. The journal is unaffected, so it would
            -- pass every balance check and surface only on a purchase report.
            --
            -- FactorToBase must be 1, never NULL or 0: account lines are divided by it
            -- (ROUND(FinalQty / NULLIF(FactorToBase,0), 6)) to produce the journal line's Qty.
            INSERT INTO dbo.TempPurchase
                (EmpId, PayeeId, PurchaseId, LineId, LineType, AccountId, ItemId,
                 FinalQty, FinalPrice, FinalExtTotal,
                 BillQty, BillPrice, BillExtTotal, ReceiveQty,
                 FactorToBase, Notes, ChangeStatus)
            SELECT @EmpId, @ChargePayeeId, 0,
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
                   'A', r.AccountId, NULL,
                   1, r.Amount, r.Amount,
                   1, r.Amount, r.Amount, 1,
                   1, r.Notes, NULL
            FROM #Resolving AS r
            -- 2026-08-12 per-line vendor: this vendor's lines only.
            WHERE r.PayeeId = @ChargePayeeId;

            EXEC dbo.VendorPayment_InsertPayNow
                @VendorPaymentId = 0,
                @PayeeId         = @ChargePayeeId,
                @PaymentDate     = @PostedDate,          -- same date as the payment (D3)
                @PaymentMethod   = @ChargeMethod,
                @FromAccountId   = @BankAccountId,
                @ReferenceId     = @ReferenceId,
                -- 2026-08-12 per-line vendor: this vendor's own total (was @ResolvingTotal).
                @PaymentAmount   = @ChargeVendorTotal,
                @Notes           = @Notes,
                @EmpId           = @EmpId,
                @NewPaymentId    = @ChargePaymentId OUTPUT;

            IF @ChargePaymentId IS NULL OR @ChargePaymentId <= 0
                THROW 50138, 'The bank charge could not be created.', 1;

            -- Same journal lookup idiom as step F. Read PaymentType back rather than assuming
            -- 'Check': VendorPayment_InsertPayNow rewrites it from @PaymentMethod, so a credit
            -- card charge is 'Credit Card Charge' and the lookup key differs.
            SELECT @ChargeNumber = PaymentNumber,
                   @ChargeType   = PaymentType
            FROM dbo.VendorPayment
            WHERE VendorPaymentId = @ChargePaymentId;

            SELECT @RowCheck = COUNT(*), @ChargeTxId = MIN(TxId)
            FROM dbo.TransactionJournal
            WHERE SourceDocType   = @ChargeType
              AND SourceDocNumber = @ChargeNumber;

            IF @RowCheck <> 1
                THROW 50139, 'Could not identify the journal transaction for the bank charge.', 1;

            SELECT @RowCheck = COUNT(*), @ChargeTxDetail = MIN(TxDetailId)
            FROM dbo.TransactionJournalDetail
            WHERE TxId = @ChargeTxId
              AND AccountId = @BankAccountId;

            IF @RowCheck <> 1
                THROW 50139, 'Could not identify the bank line of the bank charge journal.', 1;

            -- 2026-08-11 multi-vendor: the charge's BankFeedSource row moves here from the old
            -- step G (which is now inside the vendor loop). Content unchanged from 4b.
            -- 2026-08-12 per-line vendor: one row per charge vendor; AppliedAmount is THIS
            -- vendor's own total (was the whole @ResolvingTotal).
            INSERT INTO dbo.BankFeedSource
                (BankFeedTransactionId, SourceDocType, SourceDocId, TxId,
                 [Mode], [Status], OriginalBankAmount, AppliedAmount, DifferenceAmount,
                 DifferenceResolution, DifferenceMemo, CreatedAt, CreatedBy)
            VALUES
                (@BankFeedTransactionId, 'VendorPayment', @ChargePaymentId, @ChargeTxId,
                 'ResolveDifference', 'Active', @BankAmount, @ChargeVendorTotal, 0,
                 -- The charge closes its own bill in full, so it has no difference of its own.
                 'None', @DifferenceMemo, SYSUTCDATETIME(), @EmpId);

            -- 2026-08-12 per-line vendor: collect each charge's bank line here; step H no
            -- longer appends a single scalar charge item.
            INSERT INTO @MatchItems (TxId, TxDetailId) VALUES (@ChargeTxId, @ChargeTxDetail);

            FETCH NEXT FROM charge_cursor INTO @ChargePayeeId, @ChargeVendorTotal;
            END

            CLOSE charge_cursor;
            DEALLOCATE charge_cursor;
        END

        -----------------------------------------------------------------------------------
        -- H. Match through the existing path, so create and manual match cannot drift.
        --    It re-validates account / amount / not-already-matched / not-locked, sets the
        --    journal BankDate (VendorPayment_Insert leaves it NULL on new payments), and
        --    moves the header to Matched.
        --
        --    2026-08-11 multi-vendor: passes ONE item per generated payment plus the charge
        --    when present. BankFeed_MatchTx sums every bank line and compares the total to
        --    the bank amount - the second line of defence behind 50112 - and it is the same
        --    procedure manual match uses, so the two paths cannot drift apart.
        --
        --    2026-08-12 per-line vendor: the charge loop appends its items to @MatchItems
        --    directly, so the scalar UNION ALL append is retired.
        -----------------------------------------------------------------------------------
        DECLARE @MatchItemsJson NVARCHAR(MAX) =
            (SELECT TxId, TxDetailId
             FROM @MatchItems
             --FROM (SELECT TxId, TxDetailId FROM @MatchItems
             --      UNION ALL
             --      SELECT @ChargeTxId, @ChargeTxDetail WHERE @ChargePaymentId IS NOT NULL) AS m
             FOR JSON PATH);

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
