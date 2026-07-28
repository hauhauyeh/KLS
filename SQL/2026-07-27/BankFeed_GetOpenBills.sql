SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- BankFeed_GetOpenBills - candidate open vendor bills for a pending money-out bank feed row.
--   Plan: plan/bank-feed-create-phase-1-open-bill.md  (Slice 2)
--
-- Read-only. Creates no payment and no match.
--
-- Open-bill rule is NOT invented here - it is copied from VendorPayment_Inject, which is
-- what the manual vendor payment screen uses:
--     AmountDue <> 0 AND PayeeId = @PayeeId AND StageId = 6
-- narrowed to AmountDue > 0, because a vendor credit (negative AmountDue) cannot be
-- consumed by an ApplyAmount > 0 line. Credits belong to the overpayment/advance phase.
--
-- Purchase.IsLocked is deliberately NOT filtered on. VendorPayment_UpdatePurchase sets it
-- to 1 whenever AmountDue <> PurchaseTotal, so every partially paid bill is "locked" -
-- filtering on it would hide exactly the bills this feature exists to pay.
--
-- Static parameterised SQL, unlike BankFeed_GetAllList's dynamic string building: the
-- filter set here is fixed, so there is nothing to build and no injection surface.
-- =============================================================================================

CREATE OR ALTER PROCEDURE [dbo].[BankFeed_GetOpenBills]
    @BankFeedTransactionId BIGINT,
    @PayeeId               INT,
    @Search                NVARCHAR(100) = NULL,
    @Pageno                INT           = 1,
    @Pagesize              INT           = 25,
    @IsCount               BIT           = 0,
    @TotalCount            INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Validate the bank feed row is a usable money-out candidate
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
        THROW 50201, 'Bank feed transaction not found.', 1;
    IF @Status <> 'Pending'
        THROW 50202, 'Only pending bank feed transactions can create a payment.', 1;
    IF @BankAmount >= 0
        THROW 50203, 'Only money-out bank feed transactions can pay open bills.', 1;
    IF @BankAccountId IS NULL
        THROW 50204, 'This bank feed row is not mapped to a GL account.', 1;
    IF @PayeeId IS NULL OR @PayeeId <= 0
        THROW 50205, 'Please select a vendor.', 1;

    DECLARE @BankPaid DECIMAL(18,2) = ABS(@BankAmount);

    -- 2. Count pass - the paging contract BankFeed_GetAllList already uses
    IF @IsCount = 1
    BEGIN
        SELECT @TotalCount = COUNT(*)
        FROM dbo.Purchase AS p
        WHERE p.PayeeId   = @PayeeId
          AND p.StageId   = 6
          AND p.AmountDue > 0
          AND (@Search IS NULL
               OR CAST(p.PurchaseNumber AS VARCHAR(50)) LIKE '%' + @Search + '%'
               OR p.VendorDocNumber LIKE '%' + @Search + '%');

        RETURN;
    END;

    -- 3. Page pass.
    --    SuggestedApplyAmount fills oldest-first from what is left of the bank amount.
    --    The running total is computed over the WHOLE filtered set before paging, so the
    --    suggestion on page 2 still accounts for the bills on page 1.
    --    It is a UI convenience only - BankFeed_CreateVendorPayment never trusts it and
    --    validates the ApplyAmount values the client actually sends.
    WITH OpenBills AS
    (
        SELECT
            p.PurchaseId,
            p.PurchaseNumber,
            p.PayeeId,
            pay.PayeeName            AS VendorName,
            p.VendorDocNumber,
            p.PurchaseDate,
            p.DueDate,
            p.Aging,
            p.PurchaseTotal,
            p.AmountDue,
            SUM(p.AmountDue) OVER (
                ORDER BY p.DueDate, p.PurchaseId
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) - p.AmountDue AS PriorTotal
        FROM dbo.Purchase AS p
        JOIN dbo.Payee AS pay
            ON pay.PayeeId = p.PayeeId
        WHERE p.PayeeId   = @PayeeId
          AND p.StageId   = 6
          AND p.AmountDue > 0
          AND (@Search IS NULL
               OR CAST(p.PurchaseNumber AS VARCHAR(50)) LIKE '%' + @Search + '%'
               OR p.VendorDocNumber LIKE '%' + @Search + '%')
    )
    SELECT
        ob.PurchaseId,
        ob.PurchaseNumber,
        ob.PayeeId,
        ob.VendorName,
        ob.VendorDocNumber,
        ob.PurchaseDate,
        ob.DueDate,
        ob.Aging,
        ob.PurchaseTotal,
        ob.AmountDue,
        CASE
            WHEN @BankPaid - ob.PriorTotal <= 0 THEN CAST(0 AS DECIMAL(18,2))
            ELSE CASE
                     WHEN ob.AmountDue < @BankPaid - ob.PriorTotal
                     THEN ob.AmountDue
                     ELSE @BankPaid - ob.PriorTotal
                 END
        END AS SuggestedApplyAmount
    FROM OpenBills AS ob
    ORDER BY ob.DueDate, ob.PurchaseId
    OFFSET (@Pagesize * (@Pageno - 1)) ROWS
    FETCH NEXT @Pagesize ROWS ONLY;
END
GO
