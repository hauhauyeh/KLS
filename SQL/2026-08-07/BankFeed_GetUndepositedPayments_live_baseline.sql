
-- =============================================================================================
-- BankFeed_GetUndepositedPayments - candidate undeposited customer payments for a pending
-- money-in bank feed row (Create Deposit modal, Phase 2a).
--   Plan: plan/bank-feed-create-phase-2-open-invoice.md  (Slice 2)
--
-- Read-only. Creates no deposit and no match.
--
-- The candidate rule is NOT invented here - it is copied from Deposit_Inject, which is what
-- the manual Deposit screen seeds its grid from:
--     IsLocked = 0 AND PaymentType IN ('Actual Payment', 'Vendor Refund')
-- CustomerPayment.IsLocked = 1 means "already deposited" (set by Deposit_Insert, reset by
-- TRG_Delete_TFTx) - unlike Purchase.IsLocked, this one is a real flag and the correct filter.
--
-- No payee filter, unlike BankFeed_GetOpenBills: a deposit is a batch across customers by
-- nature (plan D5), so Search is a convenience and never a gate.
--
-- No SuggestedApplyAmount either: a deposit takes each payment's FULL PaymentAmount (verified
-- 2026-08-06 - zero partial-amount rows in 23,926 live TransferFundDetail rows), so picking
-- which payments compose the bank total is a selection problem the user solves, not a
-- fill-forward the SP can precompute.
--
-- Error numbers 50501+ - clear of BankFeed_MatchTx (50001+), Phase 1 create (50101+),
-- Phase 1 lookup (50201+), Phase 1 reverse (50301+), Phase 2 create (50401+).
--
-- Static parameterised SQL: fixed filter set, nothing to build, no injection surface.
-- =============================================================================================

CREATE   PROCEDURE [dbo].[BankFeed_GetUndepositedPayments]   -- EXEC dbo.BankFeed_GetUndepositedPayments @BankFeedTransactionId=1, @Search=NULL, @Pageno=1, @Pagesize=25, @IsCount=0, @TotalCount=NULL
    @BankFeedTransactionId BIGINT,
    @Search                NVARCHAR(100) = NULL,
    @Pageno                INT           = 1,
    @Pagesize              INT           = 25,
    @IsCount               BIT           = 0,
    @TotalCount            INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Validate the bank feed row is a usable money-in candidate
    DECLARE @Status         VARCHAR(20),
            @BankAmount     DECIMAL(18,2),
            @BankAccountId  INT;

    SELECT @Status        = bft.[Status],
           @BankAmount    = bft.Amount,
           @BankAccountId = bfa.AccountId
    FROM dbo.BankFeedTransaction AS bft
    LEFT JOIN dbo.BankFeedAccount AS bfa
        ON bfa.BankFeedAccountId = bft.BankFeedAccountId
    WHERE bft.BankFeedTransactionId = @BankFeedTransactionId;

    IF @Status IS NULL
        THROW 50501, 'Bank feed transaction not found.', 1;
    IF @Status <> 'Pending'
        THROW 50502, 'Only pending bank feed transactions can create a deposit.', 1;
    IF @BankAmount <= 0
        THROW 50503, 'Only money-in bank feed transactions can create a deposit.', 1;
    IF @BankAccountId IS NULL
        THROW 50504, 'This bank feed row is not mapped to a GL account.', 1;

    -- 2. Count pass - the paging contract BankFeed_GetOpenBills already uses
    IF @IsCount = 1
    BEGIN
        SELECT @TotalCount = COUNT(*)
        FROM dbo.CustomerPayment AS cp
        JOIN dbo.Payee AS pay
            ON pay.PayeeId = cp.PayeeId
        WHERE cp.IsLocked = 0
          AND cp.PaymentType IN ('Actual Payment', 'Vendor Refund')
          AND (@Search IS NULL
               OR pay.PayeeName LIKE '%' + @Search + '%'
               OR CAST(cp.PaymentNumber AS VARCHAR(50)) LIKE '%' + @Search + '%'
               OR cp.ReferenceId LIKE '%' + @Search + '%');

        RETURN;
    END;

    -- 3. Page pass, newest first - recent payments are the ones a fresh bank deposit covers
    SELECT
        cp.CustomerPaymentId,
        cp.PaymentNumber,
        cp.PayeeId,
        pay.PayeeName        AS CustomerName,
        cp.PaymentDate,
        cp.PaymentType,
        cp.PaymentMethod,
        cp.ReferenceId,
        cp.PaymentAmount
    FROM dbo.CustomerPayment AS cp
    JOIN dbo.Payee AS pay
        ON pay.PayeeId = cp.PayeeId
    WHERE cp.IsLocked = 0
      AND cp.PaymentType IN ('Actual Payment', 'Vendor Refund')
      AND (@Search IS NULL
           OR pay.PayeeName LIKE '%' + @Search + '%'
           OR CAST(cp.PaymentNumber AS VARCHAR(50)) LIKE '%' + @Search + '%'
           OR cp.ReferenceId LIKE '%' + @Search + '%')
    ORDER BY cp.PaymentDate DESC, cp.CustomerPaymentId DESC
    OFFSET (@Pagesize * (@Pageno - 1)) ROWS
    FETCH NEXT @Pagesize ROWS ONLY;
END
