-- ============================================================
-- OpenBalanceAR_AppendOneCustomer.sql
-- 2026-08-14: One-off data script. Appends ONE customer opening AR
-- invoice WITHOUT touching the existing opening rows, so already-paid
-- opening invoices are left alone (the full re-import path is blocked
-- once any OB invoice has payments applied -- error 51024).
--
-- What it does, mirroring the AR branch of OpenBalance_Import:
--   1. Validates the payee, invoice number, and reserved number range.
--   2. Inserts one Sales header (DocType='OB', next SalesNumber in
--      90000-99999, StageId 4, AmountDue = full amount).
--   3. Inserts the matching OpenBalanceAR staging row.
--   4. EXEC OpenBalance_Post 'AR' -- unposts GJ -1 and rebuilds it from
--      the FULL OpenBalanceAR table (old rows + this one). Safe with
--      payments applied: the OB journal always carries ORIGINAL invoice
--      amounts; customer-payment journals are separate documents.
--
-- Run: sqlcmd -S RAJNI\SQLEXPRESS -d KLS-2026 -C -b -i OpenBalanceAR_AppendOneCustomer.sql
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

------------------------------------------------------------------
-- EDIT THESE FOUR VALUES
------------------------------------------------------------------
DECLARE @PayeeId       INT           = 0;            -- customer PayeeId (required)
DECLARE @InvoiceNumber NVARCHAR(50)  = NULL;         -- client's own invoice number; NULL if none
DECLARE @InvoiceDate   DATE          = NULL;         -- NULL = use SYSTEM_START_DATE
DECLARE @Amount        DECIMAL(18,2) = 0;            -- open amount (required, <> 0)
DECLARE @Notes         NVARCHAR(400) = NULL;
------------------------------------------------------------------

DECLARE @AsOfDate       DATE;
DECLARE @NextSalesNumber INT;
DECLARE @SalesId        INT;
DECLARE @SalesDocNumber NVARCHAR(50);

SELECT @AsOfDate = SettingValue
FROM dbo.SystemSetting
WHERE SettingKey = 'SYSTEM_START_DATE';

IF @AsOfDate IS NULL
    THROW 51002, 'SYSTEM_START_DATE is not configured in SystemSetting.', 1;

IF ISNULL(@PayeeId, 0) = 0 OR ISNULL(@Amount, 0) = 0
    THROW 51013, 'Set @PayeeId and a non-zero @Amount at the top of the script.', 1;

-- Must be an existing customer payee (same check as import errors 51014/51015).
IF NOT EXISTS (
    SELECT 1
    FROM dbo.Customer c
    INNER JOIN dbo.Payee pay ON pay.PayeeId = c.PayeeId
    WHERE c.PayeeId = @PayeeId
      AND ISNULL(pay.PayeeType, '') = 'C'
)
    THROW 51015, 'PayeeId is not an existing customer.', 1;

-- Duplicate invoice number for the same customer: against existing opening
-- rows and against real (non-OB) sales, same as import errors 51018/51019.
IF @InvoiceNumber IS NOT NULL AND EXISTS (
    SELECT 1 FROM dbo.OpenBalanceAR
    WHERE PayeeId = @PayeeId AND SalesNum = @InvoiceNumber
)
    THROW 51018, 'This customer already has an opening AR row with this invoice number.', 1;

IF @InvoiceNumber IS NOT NULL AND EXISTS (
    SELECT 1 FROM dbo.Sales
    WHERE ShipId = @PayeeId
      AND SalesDocNumber = @InvoiceNumber
      AND ISNULL(DocType, '') <> 'OB'
)
    THROW 51019, 'This invoice number already exists for the same customer on a non-opening sale.', 1;

-- Next number in the reserved opening AR block (same rule as the import).
SELECT @NextSalesNumber =
    ISNULL(MAX(CASE
        WHEN DocType = 'OB' AND SalesNumber BETWEEN 90000 AND 99999
        THEN SalesNumber
    END), 89999) + 1
FROM dbo.Sales;

IF @NextSalesNumber >= 100000
    THROW 51011, 'Reserved opening AR SalesNumber range 90000-99999 is exhausted.', 1;

SET @SalesDocNumber = COALESCE(@InvoiceNumber,
                               CONCAT('OB-AR-', CONVERT(NVARCHAR(20), @NextSalesNumber)));

BEGIN TRAN;

    -- Serialise against a concurrent AR import, same lock key it uses.
    DECLARE @LockResult INT;
    EXEC @LockResult = sp_getapplock
        @Resource = 'AR', @LockMode = 'Exclusive',
        @LockOwner = 'Transaction', @DbPrincipal = 'public', @LockTimeout = 15000;
    IF @LockResult < 0
        THROW 51003, 'An AR opening balance import is running. Try again in a moment.', 1;

    -- Sales header: identical column set and values to OpenBalance_Import AR.
    INSERT INTO dbo.Sales
        (SalesNumber, StageId, SalesDate, ShipDate, ShipId, BillId, SalesRepId, TermId,
         SubTotal, DiscountTotal, TaxableTotal, TaxPercent, TaxTotal, SalesTotal, AmountDue,
         PaymentApplied, DiscountApplied, Instruction, ShippingCarrierId,
         IsLoadSeparate, IsLocked, IsStatementAttached, IsDropShip,
         CreatedAt, DocType, SalesDocNumber)
    SELECT
        @NextSalesNumber,
        4,
        CONVERT(DATETIME, ISNULL(@InvoiceDate, @AsOfDate)),
        ISNULL(@InvoiceDate, @AsOfDate),
        @PayeeId,
        c.BillId,
        c.SalesRepId,
        pay.TermId,
        @Amount,
        0,
        0,
        ISNULL(c.TaxRate, 0),
        0,
        @Amount,
        @Amount,
        0,
        0,
        LEFT(CONCAT('Opening AR append', CASE WHEN @Notes IS NULL THEN '' ELSE ': ' + @Notes END), 300),
        c.ShippingCarrierId,
        0, 0, 0, 0,
        GETUTCDATE(),
        'OB',
        @SalesDocNumber
    FROM dbo.Customer c
    INNER JOIN dbo.Payee pay ON pay.PayeeId = c.PayeeId
    WHERE c.PayeeId = @PayeeId;

    IF @@ROWCOUNT <> 1
        THROW 51060, 'Sales header insert affected 0 rows.', 1;

    SET @SalesId = SCOPE_IDENTITY();

    -- Staging row: SalesNum = what the client typed (NULL when blank).
    INSERT INTO dbo.OpenBalanceAR
        (SalesId, SalesNum, PayeeId, AsOfDate, Amount, Notes, CreatedAt)
    VALUES
        (@SalesId, @InvoiceNumber, @PayeeId, @AsOfDate, @Amount, @Notes, GETUTCDATE());

    -- Rebuild GJ -1 from the full staging table (old rows + this one).
    EXEC dbo.OpenBalance_Post @Section = 'AR';

COMMIT;

-- Result summary
SELECT
    s.SalesId, s.SalesNumber, s.SalesDocNumber, s.SalesDate,
    s.SalesTotal, s.AmountDue, s.DocType,
    o.SalesNum AS ClientInvoiceNumber, o.Amount, o.AsOfDate
FROM dbo.Sales s
INNER JOIN dbo.OpenBalanceAR o ON o.SalesId = s.SalesId
WHERE s.SalesId = @SalesId;

SELECT GJNumber, GjDate, TotalDebitAmount, TotalCreditAmount, Notes
FROM dbo.GeneralJournal
WHERE GJNumber = -1;
