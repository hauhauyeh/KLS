/* Update_OB_AR_OneCustomer.sql  (GUS_2026)
   Updates ONE Opening Balance AR invoice and keeps every dependent place in sync.
   In GUS_2026 the OB AR data lives in FOUR places that have no sync triggers:
     1. dbo.OpenBalanceAR          - staging, one row per OB invoice (source table)
     2. dbo.Sales                  - real OB document (DocType='OB') the payment screen consumes
     3. dbo.GeneralJournalDetail   - ONE summed @AR + @OBE pair per customer (GJ 'Opening Balance - AR')
     4. dbo.TransactionJournalDetail - mirror of the journal pair
   The journal pair per customer = SUM(OpenBalanceAR.Amount) for that PayeeId,
   so after changing the invoice row the script re-derives the customer total.

   HOW TO USE: set @SalesNum (OpenBalanceAR.SalesNum of the OB invoice) and
   @NewAmount, run the whole script. Negative @NewAmount = credit memo balance.
   CrDeAmount is derived via Fn_Adjust_CrDeAmount - never hardcoded signs. */

USE [GUS_2026];
SET XACT_ABORT ON;
SET NOCOUNT ON;

DECLARE @SalesNum  NVARCHAR(50)  = '';     -- <<< SET: OB invoice number (OpenBalanceAR.SalesNum)
DECLARE @NewAmount DECIMAL(18,2) = 0.00;   -- <<< SET: new amount for THIS invoice

---------------------------------------------------------------
-- Resolve the staging row, OB journal, and accounts (fail fast)
---------------------------------------------------------------
DECLARE @OpenARId INT, @SalesId INT, @PayeeId INT, @OldAmount DECIMAL(18,2);

SELECT @OpenARId = OpenARId, @SalesId = SalesId, @PayeeId = PayeeId, @OldAmount = Amount
FROM dbo.OpenBalanceAR
WHERE SalesNum = @SalesNum;

IF @OpenARId IS NULL
BEGIN
    RAISERROR('No OpenBalanceAR row found for this SalesNum - aborting.', 16, 1);
    RETURN;
END

DECLARE @GjId INT, @TxId BIGINT, @ARAccountId INT, @OBEAccountId INT;

SELECT @GjId = GJId FROM dbo.GeneralJournal WHERE Notes = 'Opening Balance - AR';

SELECT @TxId = TxId FROM dbo.TransactionJournal
WHERE SourceDocType = 'General Journal'
  AND SourceDocNumber = (SELECT GJNumber FROM dbo.GeneralJournal WHERE GJId = @GjId);

SELECT @ARAccountId  = AccountId FROM dbo.Account WHERE AccountCode = '@AR';
SELECT @OBEAccountId = AccountId FROM dbo.Account WHERE AccountCode = '@OBE';

IF @GjId IS NULL OR @TxId IS NULL OR @ARAccountId IS NULL OR @OBEAccountId IS NULL
BEGIN
    RAISERROR('OB AR journal or @AR/@OBE account not found - aborting.', 16, 1);
    RETURN;
END

---------------------------------------------------------------
-- Before snapshot
---------------------------------------------------------------
SELECT 'BEFORE staging' AS Src, OpenARId, SalesNum, PayeeId, Amount FROM dbo.OpenBalanceAR WHERE OpenARId = @OpenARId;
SELECT 'BEFORE sales' AS Src, SalesId, SalesNumber, DocType, SubTotal, SalesTotal, AmountDue, PaymentApplied FROM dbo.Sales WHERE SalesId = @SalesId;
SELECT 'BEFORE GJD' AS Src, d.GJDetailId, a.AccountCode, d.Amount, d.CrDeAmount, d.DebitAmount, d.CreditAmount
FROM dbo.GeneralJournalDetail d JOIN dbo.Account a ON a.AccountId = d.AccountId
WHERE d.GJId = @GjId AND d.PayeeId = @PayeeId;

BEGIN TRAN;

    ---------------------------------------------------------------
    -- 1) Staging source table
    ---------------------------------------------------------------
    UPDATE dbo.OpenBalanceAR SET Amount = @NewAmount WHERE OpenARId = @OpenARId;
    IF @@ROWCOUNT <> 1 BEGIN ROLLBACK; RAISERROR('Expected exactly 1 OpenBalanceAR row.', 16, 1); RETURN; END

    ---------------------------------------------------------------
    -- 2) OB Sales document (what the payment screen applies against).
    --    AmountDue preserves any payment already applied.
    ---------------------------------------------------------------
    UPDATE dbo.Sales
    SET SubTotal   = @NewAmount,
        SalesTotal = @NewAmount,
        AmountDue  = @NewAmount - ISNULL(PaymentApplied, 0),
        UpdatedAt  = GETUTCDATE()
    WHERE SalesId = @SalesId AND DocType = 'OB';
    IF @@ROWCOUNT <> 1 BEGIN ROLLBACK; RAISERROR('Expected exactly 1 OB Sales row.', 16, 1); RETURN; END

    ---------------------------------------------------------------
    -- 3) Journal pair = customer total re-derived from staging
    ---------------------------------------------------------------
    DECLARE @CustTotal DECIMAL(18,2);
    SELECT @CustTotal = SUM(ISNULL(Amount, 0)) FROM dbo.OpenBalanceAR WHERE PayeeId = @PayeeId;

    DECLARE @ARCrDeAmt DECIMAL(18,2) = 0, @OBECrDeAmt DECIMAL(18,2) = 0;
    EXEC dbo.Fn_Adjust_CrDeAmount '@AR',  @CustTotal, @ARCrDeAmt  OUTPUT;
    EXEC dbo.Fn_Adjust_CrDeAmount '@OBE', @CustTotal, @OBECrDeAmt OUTPUT;

    UPDATE dbo.GeneralJournalDetail
    SET Amount       = @CustTotal,
        CrDeAmount   = @ARCrDeAmt,
        CreditAmount = CASE WHEN @ARCrDeAmt > 0 THEN @ARCrDeAmt ELSE 0 END,
        DebitAmount  = CASE WHEN @ARCrDeAmt <= 0 THEN ABS(@ARCrDeAmt) ELSE 0 END
    WHERE GJId = @GjId AND PayeeId = @PayeeId AND AccountId = @ARAccountId;
    IF @@ROWCOUNT <> 1 BEGIN ROLLBACK; RAISERROR('Expected exactly 1 GJD @AR row.', 16, 1); RETURN; END

    UPDATE dbo.GeneralJournalDetail
    SET Amount       = @CustTotal,
        CrDeAmount   = @OBECrDeAmt,
        CreditAmount = CASE WHEN @OBECrDeAmt > 0 THEN @OBECrDeAmt ELSE 0 END,
        DebitAmount  = CASE WHEN @OBECrDeAmt <= 0 THEN ABS(@OBECrDeAmt) ELSE 0 END
    WHERE GJId = @GjId AND PayeeId = @PayeeId AND AccountId = @OBEAccountId;
    IF @@ROWCOUNT <> 1 BEGIN ROLLBACK; RAISERROR('Expected exactly 1 GJD @OBE row.', 16, 1); RETURN; END

    UPDATE dbo.TransactionJournalDetail
    SET Amount = @CustTotal, CrDeAmount = @ARCrDeAmt
    WHERE TxId = @TxId AND PayeeId = @PayeeId AND AccountId = @ARAccountId;
    IF @@ROWCOUNT <> 1 BEGIN ROLLBACK; RAISERROR('Expected exactly 1 TJD @AR row.', 16, 1); RETURN; END

    UPDATE dbo.TransactionJournalDetail
    SET Amount = @CustTotal, CrDeAmount = @OBECrDeAmt
    WHERE TxId = @TxId AND PayeeId = @PayeeId AND AccountId = @OBEAccountId;
    IF @@ROWCOUNT <> 1 BEGIN ROLLBACK; RAISERROR('Expected exactly 1 TJD @OBE row.', 16, 1); RETURN; END

    ---------------------------------------------------------------
    -- 4) GJ header totals (recompute from detail)
    ---------------------------------------------------------------
    UPDATE gj
    SET TotalDebitAmount  = x.TotalDebit,
        TotalCreditAmount = x.TotalCredit
    FROM dbo.GeneralJournal gj
    CROSS APPLY (SELECT SUM(ISNULL(DebitAmount,0))  AS TotalDebit,
                        SUM(ISNULL(CreditAmount,0)) AS TotalCredit
                 FROM dbo.GeneralJournalDetail WHERE GJId = @GjId) x
    WHERE gj.GJId = @GjId;

COMMIT;

---------------------------------------------------------------
-- After snapshot + balance proof (journal must sum to 0)
---------------------------------------------------------------
SELECT 'AFTER staging' AS Src, OpenARId, SalesNum, PayeeId, Amount FROM dbo.OpenBalanceAR WHERE OpenARId = @OpenARId;
SELECT 'AFTER sales' AS Src, SalesId, SalesNumber, SubTotal, SalesTotal, AmountDue, PaymentApplied FROM dbo.Sales WHERE SalesId = @SalesId;
SELECT 'AFTER GJD' AS Src, d.GJDetailId, a.AccountCode, d.Amount, d.CrDeAmount, d.DebitAmount, d.CreditAmount
FROM dbo.GeneralJournalDetail d JOIN dbo.Account a ON a.AccountId = d.AccountId
WHERE d.GJId = @GjId AND d.PayeeId = @PayeeId;

SELECT 'Staging vs journal (must match)' AS Chk,
       (SELECT SUM(Amount) FROM dbo.OpenBalanceAR WHERE PayeeId = @PayeeId) AS StagingTotal,
       (SELECT Amount FROM dbo.GeneralJournalDetail WHERE GJId = @GjId AND PayeeId = @PayeeId AND AccountId = @ARAccountId) AS JournalAR;

SELECT 'TJD CrDe sum (must be 0)' AS Chk, SUM(CrDeAmount) AS TotalCrDe
FROM dbo.TransactionJournalDetail WHERE TxId = @TxId;
