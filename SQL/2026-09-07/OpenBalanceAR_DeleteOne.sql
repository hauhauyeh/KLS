-- ============================================================
-- OpenBalanceAR_DeleteOne.sql
-- 2026-09-07: One-off data script. Deletes ONE customer opening AR
-- invoice and keeps every dependent place in sync. Counterpart of
-- OpenBalanceAR_AppendOneCustomer.sql (2026-08-14).
--
-- OB AR lives in three places:
--   1. dbo.OpenBalanceAR              staging row (source table)
--   2. dbo.Sales (DocType='OB')       document the payment screen consumes
--   3. GJ -1 'Opening Balance - AR'   one @AR/@OBE pair per customer,
--                                     mirrored into TransactionJournal(Detail)
--
-- What it does:
--   1. Resolves the OB Sales row by SalesNumber (reserved 90000-99999 block).
--   2. Refuses if the invoice has ANY payment application or cart link
--      (same checks as OpenBalance_Import errors 51020-51028).
--   3. Deletes the staging row, then the Sales row. The Sales delete goes
--      through TRG_Delete_SalesTx (INSTEAD OF); for an OB row it finds no
--      'Sales' journal and just refreshes the payee aging.
--   4. EXEC OpenBalance_Post 'AR' -- unposts GJ -1 and rebuilds it from the
--      FULL OpenBalanceAR table, so the customer's @AR/@OBE pair shrinks by
--      this invoice (or disappears if it was their only one). Safe with
--      payments applied on OTHER OB invoices: the OB journal always carries
--      original invoice amounts; customer-payment journals are separate docs.
--
-- Run: sqlcmd -S RAJNI\SQLEXPRESS -d KLS-2026 -C -b -i OpenBalanceAR_DeleteOne.sql
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

------------------------------------------------------------------
-- EDIT THIS VALUE
------------------------------------------------------------------
DECLARE @SalesNumber INT = 0;      -- <<< SET: our OB SalesNumber (90000-99999)
------------------------------------------------------------------

DECLARE @SalesId INT, @PayeeId INT, @OpenARId INT;

SELECT @SalesId = s.SalesId, @PayeeId = s.ShipId, @OpenARId = o.OpenARId
FROM dbo.Sales s
LEFT JOIN dbo.OpenBalanceAR o ON o.SalesId = s.SalesId
WHERE s.SalesNumber = @SalesNumber
  AND s.DocType = 'OB';

IF @SalesId IS NULL
    THROW 51070, 'No OB Sales row found for this SalesNumber - aborting.', 1;

IF @OpenARId IS NULL
    THROW 51071, 'OB Sales row has no OpenBalanceAR staging row - aborting, inspect manually.', 1;

-- Link checks: mirror OpenBalance_Import so we never orphan a payment.
IF EXISTS (SELECT 1 FROM dbo.CustomerPaymentDetail WHERE SalesId = @SalesId OR SourceSalesId = @SalesId)
    THROW 51024, 'This OB invoice has payment applications. Reverse the customer payment first.', 1;

IF EXISTS (SELECT 1 FROM dbo.CustomerPayment WHERE ReturnSalesId = @SalesId)
    THROW 51023, 'This OB invoice is linked to a customer payment (ReturnSalesId).', 1;

IF EXISTS (SELECT 1 FROM dbo.TempCustomerPayment WHERE SalesId = @SalesId)
    THROW 51027, 'This OB invoice is in a customer payment cart. Clear the cart first.', 1;

IF EXISTS (SELECT 1 FROM dbo.SalesDetail WHERE SalesId = @SalesId)
    THROW 51021, 'This OB invoice has SalesDetail rows - not a plain opening row.', 1;

IF EXISTS (SELECT 1 FROM dbo.Purchase WHERE DropShipSalesId = @SalesId)
    THROW 51020, 'This OB invoice is linked to a purchase.', 1;

IF EXISTS (SELECT 1 FROM dbo.SalesRouteDetail WHERE CreditMemoSalesId = @SalesId)
    THROW 51025, 'This OB invoice is linked to a route credit memo.', 1;

IF EXISTS (SELECT 1 FROM dbo.TempSales WHERE SalesId = @SalesId OR ParentSalesNumber = @SalesNumber)
    THROW 51028, 'This OB invoice is linked to a temp sales row.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.TransactionJournal
    WHERE SourceDocNumber = @SalesNumber
      AND ISNULL(SourceDocType, '') <> 'General Journal'
)
    THROW 51029, 'This OB invoice has a non-opening transaction journal.', 1;

------------------------------------------------------------------
-- Before snapshot
------------------------------------------------------------------
SELECT 'BEFORE staging' AS Src, OpenARId, SalesId, SalesNum, PayeeId, Amount
FROM dbo.OpenBalanceAR WHERE OpenARId = @OpenARId;

SELECT 'BEFORE sales' AS Src, SalesId, SalesNumber, SalesDocNumber, ShipId, SalesTotal, AmountDue, PaymentApplied
FROM dbo.Sales WHERE SalesId = @SalesId;

SELECT 'BEFORE GJD' AS Src, d.GJDetailId, a.AccountCode, d.Amount, d.CrDeAmount
FROM dbo.GeneralJournalDetail d
INNER JOIN dbo.GeneralJournal gj ON gj.GJId = d.GJId
INNER JOIN dbo.Account a ON a.AccountId = d.AccountId
WHERE gj.GJNumber = -1 AND d.PayeeId = @PayeeId;

BEGIN TRAN;

    -- Serialise against a concurrent AR import/append, same lock key they use.
    DECLARE @LockResult INT;
    EXEC @LockResult = sp_getapplock
        @Resource = 'AR', @LockMode = 'Exclusive',
        @LockOwner = 'Transaction', @DbPrincipal = 'public', @LockTimeout = 15000;
    IF @LockResult < 0
        THROW 51003, 'An AR opening balance import is running. Try again in a moment.', 1;

    DELETE FROM dbo.OpenBalanceAR WHERE OpenARId = @OpenARId;
    IF @@ROWCOUNT <> 1
        THROW 51072, 'Expected exactly 1 OpenBalanceAR row deleted.', 1;

    -- INSTEAD OF trigger TRG_Delete_SalesTx handles this; no row-count assert.
    DELETE FROM dbo.Sales WHERE SalesId = @SalesId AND DocType = 'OB';

    IF EXISTS (SELECT 1 FROM dbo.Sales WHERE SalesId = @SalesId)
        THROW 51073, 'OB Sales row still exists after delete.', 1;

    -- Rebuild GJ -1 from the remaining staging rows.
    EXEC dbo.OpenBalance_Post @Section = 'AR';

COMMIT;

------------------------------------------------------------------
-- After snapshot + proof
------------------------------------------------------------------
SELECT 'AFTER GJD' AS Src, d.GJDetailId, a.AccountCode, d.Amount, d.CrDeAmount
FROM dbo.GeneralJournalDetail d
INNER JOIN dbo.GeneralJournal gj ON gj.GJId = d.GJId
INNER JOIN dbo.Account a ON a.AccountId = d.AccountId
WHERE gj.GJNumber = -1 AND d.PayeeId = @PayeeId;

SELECT 'Staging vs journal (must match)' AS Chk,
       (SELECT ISNULL(SUM(Amount), 0) FROM dbo.OpenBalanceAR WHERE PayeeId = @PayeeId) AS StagingTotal,
       (SELECT ISNULL(SUM(d.Amount), 0)
        FROM dbo.GeneralJournalDetail d
        INNER JOIN dbo.GeneralJournal gj ON gj.GJId = d.GJId
        INNER JOIN dbo.Account a ON a.AccountId = d.AccountId
        WHERE gj.GJNumber = -1 AND d.PayeeId = @PayeeId AND a.AccountCode = '@AR') AS JournalAR;

SELECT 'GJ -1' AS Src, GJNumber, GjDate, TotalDebitAmount, TotalCreditAmount, Notes
FROM dbo.GeneralJournal WHERE GJNumber = -1;
