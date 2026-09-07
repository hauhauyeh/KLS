-- ============================================================
-- OpenBalanceAR_ChangePayee.sql
-- 2026-09-07: One-off data script. Moves ONE customer opening AR
-- invoice from one customer (old PayeeId) to another (new PayeeId)
-- and keeps every dependent place in sync. Sibling of
-- OpenBalanceAR_DeleteOne.sql / OpenBalanceAR_AppendOneCustomer.sql.
--
-- OB AR lives in three places:
--   1. dbo.OpenBalanceAR              staging row (PayeeId)
--   2. dbo.Sales (DocType='OB')       ShipId is the customer; BillId,
--                                     SalesRepId, TermId, TaxPercent and
--                                     ShippingCarrierId come from the customer
--   3. GJ -1 'Opening Balance - AR'   one @AR/@OBE pair per customer,
--                                     mirrored into TransactionJournal(Detail)
--
-- What it does:
--   1. Resolves the OB Sales row by SalesNumber and checks it belongs to
--      @OldPayeeId. Validates @NewPayeeId is an existing customer.
--   2. Refuses if the invoice has ANY payment application or cart link:
--      a payment already applied belongs to the old customer and would be
--      orphaned by the move. Reverse the payment first, then re-run.
--   3. Refuses if the new customer already has an OB row with the same
--      client invoice number, or a real sale with that number (same rules
--      as import errors 51018/51019).
--   4. Updates the staging row and the Sales header to the new customer.
--   5. EXEC OpenBalance_Post 'AR' -- rebuilds GJ -1 from the FULL staging
--      table, so the old customer's pair shrinks and the new customer's
--      pair grows (or is created). Safe with payments on OTHER OB rows.
--   6. Refreshes aging for both payees.
--
-- Run: sqlcmd -S RAJNI\SQLEXPRESS -d KLS-2026 -C -b -i OpenBalanceAR_ChangePayee.sql
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

------------------------------------------------------------------
-- EDIT THESE THREE VALUES
------------------------------------------------------------------
DECLARE @SalesNumber INT = 0;      -- <<< SET: our OB SalesNumber (90000-99999)
DECLARE @OldPayeeId  INT = 0;      -- <<< SET: customer the invoice is on now
DECLARE @NewPayeeId  INT = 0;      -- <<< SET: customer it should move to
------------------------------------------------------------------

DECLARE @SalesId INT, @CurPayeeId INT, @OpenARId INT, @InvoiceNumber NVARCHAR(50);

IF ISNULL(@SalesNumber, 0) = 0 OR ISNULL(@OldPayeeId, 0) = 0 OR ISNULL(@NewPayeeId, 0) = 0
    THROW 51080, 'Set @SalesNumber, @OldPayeeId and @NewPayeeId at the top of the script.', 1;

IF @OldPayeeId = @NewPayeeId
    THROW 51081, 'Old and new PayeeId are the same - nothing to do.', 1;

SELECT @SalesId = s.SalesId, @CurPayeeId = s.ShipId, @OpenARId = o.OpenARId, @InvoiceNumber = o.SalesNum
FROM dbo.Sales s
LEFT JOIN dbo.OpenBalanceAR o ON o.SalesId = s.SalesId
WHERE s.SalesNumber = @SalesNumber
  AND s.DocType = 'OB';

IF @SalesId IS NULL
    THROW 51070, 'No OB Sales row found for this SalesNumber - aborting.', 1;

IF @OpenARId IS NULL
    THROW 51071, 'OB Sales row has no OpenBalanceAR staging row - aborting, inspect manually.', 1;

IF @CurPayeeId <> @OldPayeeId
    THROW 51082, 'OB Sales row is not on @OldPayeeId - check the numbers.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.OpenBalanceAR WHERE OpenARId = @OpenARId AND PayeeId = @OldPayeeId)
    THROW 51083, 'Staging row PayeeId does not match @OldPayeeId - inspect manually.', 1;

-- New payee must be an existing customer (import errors 51014/51015).
IF NOT EXISTS (
    SELECT 1
    FROM dbo.Customer c
    INNER JOIN dbo.Payee pay ON pay.PayeeId = c.PayeeId
    WHERE c.PayeeId = @NewPayeeId
      AND ISNULL(pay.PayeeType, '') = 'C'
)
    THROW 51015, '@NewPayeeId is not an existing customer.', 1;

-- Link checks: an applied payment belongs to the OLD customer, so refuse.
IF EXISTS (SELECT 1 FROM dbo.CustomerPaymentDetail WHERE SalesId = @SalesId OR SourceSalesId = @SalesId)
    THROW 51024, 'This OB invoice has payment applications. Reverse the customer payment first.', 1;

IF EXISTS (SELECT 1 FROM dbo.CustomerPayment WHERE ReturnSalesId = @SalesId)
    THROW 51023, 'This OB invoice is linked to a customer payment (ReturnSalesId).', 1;

IF EXISTS (SELECT 1 FROM dbo.TempCustomerPayment WHERE SalesId = @SalesId)
    THROW 51027, 'This OB invoice is in a customer payment cart. Clear the cart first.', 1;

IF EXISTS (SELECT 1 FROM dbo.SalesDetail WHERE SalesId = @SalesId)
    THROW 51021, 'This OB invoice has SalesDetail rows - not a plain opening row.', 1;

IF EXISTS (SELECT 1 FROM dbo.TempSales WHERE SalesId = @SalesId OR ParentSalesNumber = @SalesNumber)
    THROW 51028, 'This OB invoice is linked to a temp sales row.', 1;

-- Duplicate invoice number on the NEW customer (import errors 51018/51019).
IF @InvoiceNumber IS NOT NULL AND EXISTS (
    SELECT 1 FROM dbo.OpenBalanceAR
    WHERE PayeeId = @NewPayeeId AND SalesNum = @InvoiceNumber
)
    THROW 51018, 'The new customer already has an opening AR row with this invoice number.', 1;

IF @InvoiceNumber IS NOT NULL AND EXISTS (
    SELECT 1 FROM dbo.Sales
    WHERE ShipId = @NewPayeeId
      AND SalesDocNumber = @InvoiceNumber
      AND ISNULL(DocType, '') <> 'OB'
)
    THROW 51019, 'The new customer already has a non-opening sale with this invoice number.', 1;

------------------------------------------------------------------
-- Before snapshot
------------------------------------------------------------------
SELECT 'BEFORE staging' AS Src, OpenARId, SalesId, SalesNum, PayeeId, Amount
FROM dbo.OpenBalanceAR WHERE OpenARId = @OpenARId;

SELECT 'BEFORE sales' AS Src, SalesId, SalesNumber, SalesDocNumber, ShipId, BillId, SalesRepId, TermId, SalesTotal, AmountDue
FROM dbo.Sales WHERE SalesId = @SalesId;

SELECT 'BEFORE GJD' AS Src, d.PayeeId, a.AccountCode, d.Amount, d.CrDeAmount
FROM dbo.GeneralJournalDetail d
INNER JOIN dbo.GeneralJournal gj ON gj.GJId = d.GJId
INNER JOIN dbo.Account a ON a.AccountId = d.AccountId
WHERE gj.GJNumber = -1 AND d.PayeeId IN (@OldPayeeId, @NewPayeeId)
ORDER BY d.PayeeId, a.AccountCode;

BEGIN TRAN;

    -- Serialise against a concurrent AR import/append, same lock key they use.
    DECLARE @LockResult INT;
    EXEC @LockResult = sp_getapplock
        @Resource = 'AR', @LockMode = 'Exclusive',
        @LockOwner = 'Transaction', @DbPrincipal = 'public', @LockTimeout = 15000;
    IF @LockResult < 0
        THROW 51003, 'An AR opening balance import is running. Try again in a moment.', 1;

    -- 1) Staging row
    UPDATE dbo.OpenBalanceAR
    SET PayeeId = @NewPayeeId
    WHERE OpenARId = @OpenARId AND PayeeId = @OldPayeeId;
    IF @@ROWCOUNT <> 1
        THROW 51084, 'Expected exactly 1 OpenBalanceAR row updated.', 1;

    -- 2) OB Sales header: same customer-derived columns the import fills.
    UPDATE s
    SET ShipId            = @NewPayeeId,
        BillId            = c.BillId,
        SalesRepId        = c.SalesRepId,
        TermId            = pay.TermId,
        TaxPercent        = ISNULL(c.TaxRate, 0),
        ShippingCarrierId = c.ShippingCarrierId,
        UpdatedAt         = GETUTCDATE()
    FROM dbo.Sales s
    CROSS JOIN dbo.Customer c
    INNER JOIN dbo.Payee pay ON pay.PayeeId = c.PayeeId
    WHERE s.SalesId = @SalesId
      AND s.DocType = 'OB'
      AND s.ShipId  = @OldPayeeId
      AND c.PayeeId = @NewPayeeId;
    IF @@ROWCOUNT <> 1
        THROW 51085, 'Expected exactly 1 OB Sales row updated.', 1;

    -- 3) Rebuild GJ -1 from the full staging table.
    EXEC dbo.OpenBalance_Post @Section = 'AR';

    -- 4) Aging for both customers.
    EXEC dbo.Payee_UpdateAging @OldPayeeId, 1;
    EXEC dbo.Payee_UpdateAging @NewPayeeId, 1;

COMMIT;

------------------------------------------------------------------
-- After snapshot + proof
------------------------------------------------------------------
SELECT 'AFTER staging' AS Src, OpenARId, SalesId, SalesNum, PayeeId, Amount
FROM dbo.OpenBalanceAR WHERE OpenARId = @OpenARId;

SELECT 'AFTER sales' AS Src, SalesId, SalesNumber, SalesDocNumber, ShipId, BillId, SalesRepId, TermId, SalesTotal, AmountDue
FROM dbo.Sales WHERE SalesId = @SalesId;

SELECT 'AFTER GJD' AS Src, d.PayeeId, a.AccountCode, d.Amount, d.CrDeAmount
FROM dbo.GeneralJournalDetail d
INNER JOIN dbo.GeneralJournal gj ON gj.GJId = d.GJId
INNER JOIN dbo.Account a ON a.AccountId = d.AccountId
WHERE gj.GJNumber = -1 AND d.PayeeId IN (@OldPayeeId, @NewPayeeId)
ORDER BY d.PayeeId, a.AccountCode;

SELECT 'Staging vs journal (must match per payee)' AS Chk,
       p.PayeeId,
       (SELECT ISNULL(SUM(Amount), 0) FROM dbo.OpenBalanceAR WHERE PayeeId = p.PayeeId) AS StagingTotal,
       (SELECT ISNULL(SUM(d.Amount), 0)
        FROM dbo.GeneralJournalDetail d
        INNER JOIN dbo.GeneralJournal gj ON gj.GJId = d.GJId
        INNER JOIN dbo.Account a ON a.AccountId = d.AccountId
        WHERE gj.GJNumber = -1 AND d.PayeeId = p.PayeeId AND a.AccountCode = '@AR') AS JournalAR
FROM (VALUES (@OldPayeeId), (@NewPayeeId)) p(PayeeId);

SELECT 'GJ -1' AS Src, GJNumber, GjDate, TotalDebitAmount, TotalCreditAmount, Notes
FROM dbo.GeneralJournal WHERE GJNumber = -1;
