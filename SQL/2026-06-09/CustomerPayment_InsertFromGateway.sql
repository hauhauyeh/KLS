SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[CustomerPayment_InsertFromGateway]
GO

CREATE PROCEDURE [dbo].[CustomerPayment_InsertFromGateway] -- EXEC CustomerPayment_InsertFromGateway @PayeeId=304036,@PaymentMethod=N'E-CHECK',@ReferenceId=N'TEST',@PaymentAmount=596.48,@SalesIds=N'70702',@Gateway=N'MX Merchant',@CCFee=0,@CardType=NULL,@Last4=NULL,@EmpId=1,@UserNotes=NULL,@NewPaymentId=0
-- EXEC CustomerPayment_InsertFromGateway @PayeeId=304036,@PaymentMethod=N'CREDIT CARD',@ReferenceId=N'TEST',@PaymentAmount=602.44,@SalesIds=N'70702',@Gateway=N'Square Payment',@CCFee=5.96,@CardType=N'VISA',@Last4=N'1234',@EmpId=1,@UserNotes=NULL,@NewPaymentId=0
-- EXEC CustomerPayment_InsertFromGateway @PayeeId=304036,@PaymentMethod=N'CREDIT CARD',@ReferenceId=N'TEST',@PaymentAmount=102.00,@SalesIds=N'',@Gateway=N'MX Merchant',@CCFee=2.00,@CardType=N'VISA',@Last4=N'1234',@EmpId=1,@UserNotes=NULL,@NewPaymentId=0
    @PayeeId INT,
    @PaymentMethod NVARCHAR(50),
    @ReferenceId NVARCHAR(100),
    @PaymentAmount DECIMAL(18,2),
    @SalesIds NVARCHAR(MAX),
    @Gateway NVARCHAR(100),
    @CCFee DECIMAL(18,2),
    @CardType NVARCHAR(50),
    @Last4 NVARCHAR(50),
    @EmpId INT,
    @UserNotes NVARCHAR(MAX) = NULL,
    @NewPaymentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PaymentDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @PaymentType NVARCHAR(50) = 'Actual Payment';

    -- Compose base Notes from the gateway label only. The optional user note
    -- and any route-specific auto-credit marker are appended in Step 7 in an
    -- order that keeps the office signal near the start (so a downstream
    -- NVARCHAR(255) truncation at CustomerPayment_Insert does not chop it off).
    DECLARE @ComposedNotes NVARCHAR(MAX) = @Gateway;

    -- ============================================================
    -- Step 1. Clear stale temp state for this EmpId.
    -- ------------------------------------------------------------
    -- TempCustomerPayment: always cleared so this call starts fresh.
    --
    -- TempExtraPayment: also cleared so an unfinished office draft disposition
    -- cannot leak into this portal payment. CustomerPayment_Insert.Phase1B
    -- reads it by (PayeeId, CustomerPaymentId=0). The 2026-05-15 version of
    -- this wrapper cleaned it; the 2026-05-22 version dropped that step --
    -- restored here.
    -- ============================================================
    DELETE FROM dbo.TempCustomerPayment
    WHERE EmpId = @EmpId;

    DELETE FROM dbo.TempExtraPayment
    WHERE EmpId = @EmpId
       OR (PayeeId = @PayeeId AND CustomerPaymentId = 0);

    -- ============================================================
    -- Step 2. Parse the raw selected SalesId set.
    -- ------------------------------------------------------------
    -- @RawSelected = exactly what the caller asked for. Preserve this
    -- regardless of ShipId / AmountDue, because Step 3 must compare raw
    -- vs valid to detect intent mismatch (e.g. wrong ShipId).
    -- ============================================================
    -- Note on the trim+NULLIF guard: SQL Server's CAST('' AS INT) returns 0,
    -- not NULL, so a TRY_CAST(...) IS NOT NULL filter alone would NOT filter
    -- an empty-string token out of STRING_SPLIT (and STRING_SPLIT('', ',')
    -- returns one empty-string row). That would silently inject a bogus
    -- SalesId=0 into @RawSelected, inflate @RawCount, and mis-route empty
    -- @SalesIds calls into WrongShipIdCredit instead of EmptyCredit.
    -- NULLIF the trimmed value to '' BEFORE casting so the WHERE actually
    -- filters out blank tokens.
    DECLARE @RawSelected TABLE (SalesId INT PRIMARY KEY);

    INSERT INTO @RawSelected (SalesId)
    SELECT DISTINCT TRY_CAST(NULLIF(LTRIM(RTRIM(value)), '') AS INT)
    FROM STRING_SPLIT(ISNULL(@SalesIds, ''), ',')
    WHERE TRY_CAST(NULLIF(LTRIM(RTRIM(value)), '') AS INT) IS NOT NULL;

    -- ============================================================
    -- Step 3. Filter to the valid (owned + open) subset.
    -- ------------------------------------------------------------
    -- Ownership = ShipId match. The portal authenticates customers by ShipId
    -- (one login = one delivery location), so @PayeeId arriving here is
    -- semantically a ShipId. AR is tracked per-Sales row, reducing
    -- Sales.AmountDue regardless of BillId.
    --
    -- 2026-06-09: previous filter used s.BillId = @PayeeId, which
    -- coincidentally worked for self-billing customers (BillId == ShipId ==
    -- @PayeeId) but silently dropped every selected row for any
    -- parent-billed customer. Change to s.ShipId fixes that class and
    -- aligns with the portal identity model.
    --
    -- Retired filter (kept for reviewer comparison):
    -- WHERE s.AmountDue <> 0 AND s.BillId = @PayeeId
    -- ============================================================
    DECLARE @ValidSelected TABLE
    (
        SalesId INT PRIMARY KEY,
        AmountDue DECIMAL(18,2) NOT NULL
    );

    INSERT INTO @ValidSelected (SalesId, AmountDue)
    SELECT s.SalesId, s.AmountDue
    FROM dbo.Sales s
    INNER JOIN @RawSelected r ON r.SalesId = s.SalesId
    WHERE s.ShipId = @PayeeId
      AND s.AmountDue <> 0;

    -- ============================================================
    -- Step 4. Compute routing metrics.
    -- ------------------------------------------------------------
    -- @RawCount        = SalesIds the caller submitted
    -- @ValidCount      = subset owned by @PayeeId (ShipId match) and still open
    -- @RejectedCount   = raw - valid; any rejection forces full auto-credit
    --                    so the office sees the customer's full intent rather
    --                    than a silent partial apply
    -- @ValidApplyTotal = net of valid AmountDue (positives + negatives = net
    --                    the customer paid at the gateway; credit memos are
    --                    inherently negative AmountDue)
    -- @Leftover        = @PaymentAmount - @CCFee - @ValidApplyTotal
    --                       > 0 overpay  -> apply selected + credit leftover
    --                       = 0 happy    -> apply selected exactly
    --                       < 0 underpay -> can't apply at face value;
    --                                       fall back to full auto-credit
    -- ============================================================
    DECLARE @RawCount        INT           = (SELECT COUNT(*) FROM @RawSelected);
    DECLARE @ValidCount      INT           = (SELECT COUNT(*) FROM @ValidSelected);
    DECLARE @RejectedCount   INT           = @RawCount - @ValidCount;
    DECLARE @ValidApplyTotal DECIMAL(18,2) = ISNULL((SELECT SUM(AmountDue) FROM @ValidSelected), 0);
    DECLARE @Leftover        DECIMAL(18,2) = @PaymentAmount - ISNULL(@CCFee, 0) - @ValidApplyTotal;

    -- ============================================================
    -- Step 5. Pick the route.
    -- ------------------------------------------------------------
    -- Routing precedence:
    --   1. EmptyCredit        - caller sent no SalesIds at all (existing
    --                           charge-now-apply-later path); makes intent
    --                           explicit rather than falling into OverpayApply
    --                           by arithmetic accident
    --   2. WrongShipIdCredit  - one or more SalesIds didn't pass ownership;
    --                           preserve intent for office review rather
    --                           than partial-apply silently
    --   3. HappyApply         - clean reconcile, no leftover
    --   4. OverpayApply       - apply selected, leftover -> credit
    --   5. UnderpayCredit     - selected sum > paid; can't apply at face value
    --
    -- After this SP runs the MX/Square gateway has ALREADY charged the
    -- customer; throwing here would leave money out of the customer's bank
    -- with no KLS record. All non-happy routes record an auditable
    -- CustomerPayment row that the office reconciles via the existing
    -- manual edit UI.
    -- ============================================================
    DECLARE @Route NVARCHAR(20) =
        CASE
            WHEN @RawCount = 0          THEN 'EmptyCredit'
            WHEN @RejectedCount > 0     THEN 'WrongShipIdCredit'
            WHEN @Leftover = 0          THEN 'HappyApply'
            WHEN @Leftover > 0          THEN 'OverpayApply'
            ELSE                             'UnderpayCredit'
        END;

    -- ============================================================
    -- Step 6. Build TempCustomerPayment only for apply routes.
    -- ------------------------------------------------------------
    -- HappyApply / OverpayApply: insert full apply rows from @ValidSelected.
    -- All other routes: skip the insert, leaving TempCustomerPayment empty
    -- so CustomerPayment_Insert posts a credit-only payment (no detail rows
    -- in DetailRole IN ('Invoice','DebitMemo')).
    --
    -- Apply amount per row = s.AmountDue (full face value). Credit memos
    -- (s.SalesTotal < 0) get negative PaymentApplied via the same column;
    -- their netting against positive invoices is already reflected in
    -- @ValidApplyTotal, and CustomerPayment_Insert handles them via
    -- @CreditMemoUsed downstream.
    -- ============================================================
    IF @Route IN ('HappyApply', 'OverpayApply')
    BEGIN
        ;WITH AllDiscount AS
        (
            SELECT
                pd.SalesId,
                SUM(ISNULL(pd.PaymentDiscount, 0)) AS AllDiscountTaken
            FROM dbo.CustomerPaymentDetail pd
            GROUP BY pd.SalesId
        )
        INSERT INTO dbo.TempCustomerPayment
        (
            EmpId,
            PayeeId,
            CustomerPaymentId,
            SalesId,
            AmountDue,
            PaymentApplied,
            PaymentDiscount,
            ShortDiscount,
            OtherDiscount,
            IsCreditMemo,
            IsCCFee,
            IsApplied,
            SourceType,
            SourceId,
            IsSelected,
            DocNumber,
            DocDate,
            Description,
            BillName,
            OriginalAmount,
            OpenBalanceBefore,
            TermName,
            DiscountPercent,
            DiscountAlreadyTaken,
            DiscountDate,
            DueDays
        )
        SELECT
            @EmpId,
            @PayeeId,
            0,
            s.SalesId,
            s.AmountDue,
            s.AmountDue,          -- full apply for selected invoices
            0,
            0,
            0,
            CASE WHEN s.SalesTotal < 0 THEN 1 ELSE 0 END,
            0,
            1,
            CASE WHEN s.SalesTotal < 0 THEN 'CreditMemo' ELSE 'Invoice' END,
            s.SalesId,
            1,
            CAST(s.SalesNumber AS NVARCHAR(30)),
            s.ShipDate,
            ps.PayeeName,
            pb.PayeeName,
            s.SalesTotal,
            s.AmountDue,
            tm.TermName,
            ISNULL(s.DiscountPercent, ISNULL(tm.Discount, 0)),
            ISNULL(ad.AllDiscountTaken, 0),
            s.DiscountDate,
            ISNULL(tm.DueDays, 0)
        FROM dbo.Sales s
        INNER JOIN @ValidSelected v
            ON v.SalesId = s.SalesId
        INNER JOIN dbo.Payee ps
            ON ps.PayeeId = s.ShipId
        INNER JOIN dbo.Payee pb
            ON pb.PayeeId = s.BillId
        LEFT JOIN dbo.Term tm
            ON tm.TermId = s.TermId
        LEFT JOIN AllDiscount ad
            ON ad.SalesId = s.SalesId;
    END;

    -- ============================================================
    -- Step 7. Set disposition + per-route Notes.
    -- ------------------------------------------------------------
    -- Disposition rules:
    --   HappyApply         - no extra disposition; inner SP posts full apply
    --   OverpayApply       - leftover -> Credit (positive, net of CCFee)
    --   UnderpayCredit     - full payment -> Credit (net of CCFee)
    --   WrongShipIdCredit  - full payment -> Credit (net of CCFee)
    --   EmptyCredit        - full payment -> Credit (net of CCFee)
    --
    -- Why credit amount is ALWAYS net (@PaymentAmount - @CCFee):
    -- CustomerPayment_Insert.Phase1D inserts a separate CCFee detail row
    -- and Phase 9A posts AR using @ExtraAmount when @AsCredit = 1. If we
    -- pass gross here, @AR overstates the customer credit by @CCFee and
    -- the journal goes out of balance by the fee, diverging the AR ledger
    -- from CustomerPayment.UnappliedAmount (which is mechanically net,
    -- computed by Phase 10A as @PaymentAmount - apply - @DirectCCFeeApplied
    -- + reuses).
    --
    -- 2026-06-09: the 2026-05-22 live version passed @PaymentAmount (gross)
    -- for the EmptyCredit path, which is a real bug for any CC payment with
    -- @CCFee > 0. Verified on local restored prod (CC payment 102.00 +
    -- 2.00 fee): live SP produces AR -102.00 + UF +102.00 + ICCF +2.00 =
    -- +2.00 unbalanced; UnappliedAmount header = 100.00 (correctly net) so
    -- header and ledger disagree by @CCFee. Net fix balances both.
    --
    -- Retired (kept for reviewer comparison):
    -- IF ISNULL(LTRIM(RTRIM(@SalesIds)), '') = ''
    -- BEGIN
    --     SET @NewExtraDisposition = 'Credit';
    --     SET @ExtraDispositionChanged = 1;
    --     SET @SelectedExtraDispositionAmount = @PaymentAmount;  -- gross, bug
    -- END;
    -- ============================================================
    DECLARE @NewExtraDisposition NVARCHAR(50) = NULL;
    DECLARE @ExtraDispositionChanged BIT = NULL;
    DECLARE @SelectedExtraDispositionAmount DECIMAL(18,2) = NULL;
    DECLARE @NetCredit DECIMAL(18,2) = @PaymentAmount - ISNULL(@CCFee, 0);

    IF @Route IN ('EmptyCredit', 'WrongShipIdCredit', 'UnderpayCredit')
    BEGIN
        SET @NewExtraDisposition = 'Credit';
        SET @ExtraDispositionChanged = 1;
        SET @SelectedExtraDispositionAmount = @NetCredit;
    END
    ELSE IF @Route = 'OverpayApply'
    BEGIN
        SET @NewExtraDisposition = 'Credit';
        SET @ExtraDispositionChanged = 1;
        SET @SelectedExtraDispositionAmount = @Leftover;
    END;

    -- Compose final Notes in an order that keeps the office signal near the
    -- start (NVARCHAR(255) truncation at the CustomerPayment_Insert parameter
    -- boundary chops the tail, not the head):
    --   <Gateway> [ -- <Auto-credit marker> ] [ -- <UserNote> ]
    --
    -- Only fallback routes get a marker. HappyApply / OverpayApply applied
    -- as intended; EmptyCredit is the intended charge-now-apply-later path.
    -- WrongShipIdCredit and UnderpayCredit are fallbacks that need office
    -- review -- scan Notes for 'Auto-credit' to surface them in the work
    -- queue.
    IF @Route = 'WrongShipIdCredit'
        SET @ComposedNotes = @ComposedNotes
            + ' -- Auto-credit/review: ShipId mismatch (rejected '
            + CAST(@RejectedCount AS NVARCHAR(10)) + ')';
    ELSE IF @Route = 'UnderpayCredit'
        SET @ComposedNotes = @ComposedNotes
            + ' -- Auto-credit: underpay (short $'
            + CAST(ABS(@Leftover) AS NVARCHAR(20)) + ')';

    IF NULLIF(LTRIM(RTRIM(@UserNotes)), '') IS NOT NULL
        SET @ComposedNotes = @ComposedNotes + ' -- ' + @UserNotes;

    -- Safety clip: CustomerPayment_Insert.@Notes is NVARCHAR(255). Cap here
    -- explicitly so the silent narrowing at the EXEC boundary cannot chop
    -- mid-marker if a particularly long user note is sent.
    SET @ComposedNotes = LEFT(@ComposedNotes, 255);

    -- ============================================================
    -- Step 8. Call the inner Insert SP.
    -- ============================================================
    EXEC dbo.CustomerPayment_Insert
        @CustomerPaymentId = 0,
        @PaymentType = @PaymentType,
        @PayeeId = @PayeeId,
        @PaymentDate = @PaymentDate,
        @PaymentMethod = @PaymentMethod,
        @FromAccountId = NULL,
        @ReferenceId = @ReferenceId,
        @PaymentAmount = @PaymentAmount,
        @Notes = @ComposedNotes,
        @CCFee = @CCFee,
        @PreviousExtraDisposition = NULL,
        @NewExtraDisposition = @NewExtraDisposition,
        @ExtraDispositionChanged = @ExtraDispositionChanged,
        @SelectedExtraDispositionAmount = @SelectedExtraDispositionAmount,
        @EmpId = @EmpId,
        @NewPaymentId = @NewPaymentId OUTPUT;

    -- Persist card / ACH metadata onto the new payment header.
    UPDATE dbo.CustomerPayment
    SET CardType = @CardType,
        Last4 = @Last4
    WHERE CustomerPaymentId = @NewPaymentId;
END
GO
