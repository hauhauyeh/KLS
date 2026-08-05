SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- ============================================================
-- OpenBalance_Import
-- 2026-08-04: NEW. The whole "Save & Import" action for ONE section.
--
--   DELETE + reload that section's OpenBalance* table   (save)
--   EXEC OpenBalance_Post @Section                      (import)
--
-- BOTH HALVES IN ONE TRANSACTION, and that is the point rather than an
-- implementation detail: either the rows and the journal both land or
-- neither does. There is no reachable state where the saved rows and
-- the posted journal disagree.
--
-- Touches ONE staging table and ONE GJNumber. The other four sections
-- are left byte-identical -- same rows, same GJId, same TxId, same
-- totals, and no RecalculationLog churn. That matters most for
-- Inventory, where a needless re-post costs ~1,858 recalc rows.
--
-- The workbook is authoritative for the WHOLE section: this is a
-- delete-and-reload, not a merge. A user who filters their sheet down
-- to three rows and imports deletes the rest. The service surfaces that
-- as a Confirm the user has to tick; @PriorRowCount is what it counts.
--
-- Every OPENROWSET string here must stay BYTE-IDENTICAL to the matching
-- one in OpenBalance_ImportPreview, IMEX=1 included. If they drift, the
-- user approves one parse and the system performs another.
--
-- 2026-08-04: Blank seeded rows are ignored with the same predicates as
-- OpenBalance_ImportPreview:
--   ACCOUNT     Balance IS NULL
--   AR/AP/ARE   Amount IS NULL
--   INV         Qty/Price/TotalValue all NULL
--
-- No @EmpId parameter: the OpenBalance* tables have no user column, and
-- a parameter that is accepted and discarded is worse than none.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[OpenBalance_Import]
    -- EXEC dbo.OpenBalance_Import @FilePath = 'C:\...\abc.xlsx', @Section = 'AR',
    --                             @RowCount = @r OUTPUT, @PriorRowCount = @p OUTPUT

    @FilePath       NVARCHAR(255),
    @Section        NVARCHAR(20),
    @RowCount       INT OUTPUT,
    @PriorRowCount  INT OUTPUT

AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Sec        NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@Section, ''))));
    DECLARE @Qry        NVARCHAR(MAX);
    DECLARE @Msg        NVARCHAR(400);
    DECLARE @AsOfDate   DATE;
    DECLARE @LockResult INT;

    SET @RowCount = 0;
    SET @PriorRowCount = 0;

    IF @Sec NOT IN ('ACCOUNT', 'AR', 'AP', 'INV', 'ARE')
    BEGIN
        SET @Msg = CONCAT(
            'Unknown opening balance section "', ISNULL(@Section, '<null>'),
            '". Expected ACCOUNT, AR, AP, INV or ARE.');

        THROW 51000, @Msg, 1;
    END

    -- Every opening balance row carries the same date by definition, so it
    -- is stamped here rather than collected per row (decision D4).
    SELECT @AsOfDate = SettingValue
    FROM dbo.SystemSetting
    WHERE SettingKey = 'SYSTEM_START_DATE';

    IF @AsOfDate IS NULL
        THROW 51002, 'SYSTEM_START_DATE is not configured in SystemSetting.', 1;

    BEGIN TRAN;

        ------------------------------------------------------------------
        -- Serialise per section. Two users importing AR at once would
        -- otherwise interleave the DELETE and the INSERT and leave a
        -- mixture of both workbooks. Keyed on the section, so importing
        -- AR never blocks importing Inventory.
        ------------------------------------------------------------------
        EXEC @LockResult = sp_getapplock
            @Resource   = @Sec,
            @LockMode   = 'Exclusive',
            @LockOwner  = 'Transaction',
            @DbPrincipal = 'public',
            @LockTimeout = 15000;

        IF @LockResult < 0
        BEGIN
            SET @Msg = CONCAT(
                'Another import of the ', @Sec, ' section is already running. Try again in a moment.');

            THROW 51003, @Msg, 1;
        END

        ------------------------------------------------------------------
        -- ACCOUNT
        ------------------------------------------------------------------
        IF @Sec = 'ACCOUNT'
        BEGIN
            DECLARE @Account AS TABLE (
                AutoId      INT IDENTITY(1,1),
                AccountCode NVARCHAR(100)  NULL,
                AccountName NVARCHAR(255)  NULL,
                Balance     DECIMAL(18,2)  NULL,
                Notes       NVARCHAR(400)  NULL
            );

            SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [Account$]);';

            INSERT INTO @Account EXEC (@Qry);

            SELECT @PriorRowCount = COUNT(*) FROM dbo.OpenBalanceAccount;

            DELETE FROM dbo.OpenBalanceAccount;

            INSERT INTO dbo.OpenBalanceAccount
                (AccountId, AccountCode, AsOfDate, Balance, Notes, CreatedAt)
            SELECT
                a.AccountId,
                t.AccountCode,
                @AsOfDate,
                ISNULL(t.Balance, 0),
                t.Notes,
                GETUTCDATE()
            FROM @Account t
            CROSS APPLY (
                SELECT MIN(x.AccountId) AS AccountId
                FROM dbo.Account x
                WHERE x.AccountCode = t.AccountCode
            ) a
            WHERE t.Balance IS NOT NULL
            ORDER BY t.AutoId;

            SET @RowCount = @@ROWCOUNT;
        END

        ------------------------------------------------------------------
        -- AR
        ------------------------------------------------------------------
        ELSE IF @Sec = 'AR'
        BEGIN
            DECLARE @AR AS TABLE (
                AutoId         INT IDENTITY(1,1),
                CustomerName   NVARCHAR(255)   NULL,
                InvoiceNumber  NVARCHAR(100)   NULL,
                InvoiceDateRaw NVARCHAR(100)   NULL,
                Amount         DECIMAL(18,2)   NULL,
                Notes          NVARCHAR(400)   NULL,
                PayeeId        INT             NULL
            );

            DECLARE @PreparedAR AS TABLE (
                RowNo            INT             NOT NULL,
                FilledSeq        INT             NOT NULL,
                CustomerName     NVARCHAR(255)   NULL,
                InvoiceNumber    NVARCHAR(100)   NULL,
                InvoiceDate      DATE            NULL,
                IsDateValid      BIT             NOT NULL,
                Amount           DECIMAL(18,2)   NOT NULL,
                Notes            NVARCHAR(400)   NULL,
                PayeeId          INT             NULL,
                SalesNumber      INT             NULL,
                SalesDocNumber   NVARCHAR(50)    NULL
            );

            DECLARE @OldOBSales AS TABLE (
                SalesId     INT NOT NULL PRIMARY KEY,
                SalesNumber INT NOT NULL
            );

            DECLARE @InsertedSales AS TABLE (
                SalesId     INT NOT NULL,
                SalesNumber INT NOT NULL
            );

            SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [AR$]);';

            INSERT INTO @AR EXEC (@Qry);

            SELECT @PriorRowCount = COUNT(*) FROM dbo.OpenBalanceAR;

            DECLARE @FilledARCount INT;
            DECLARE @NextSalesNumber INT;
            DECLARE @HasReservedCollision BIT = 0;

            SELECT @FilledARCount = COUNT(*)
            FROM @AR
            WHERE Amount IS NOT NULL;

            SELECT @HasReservedCollision =
                CASE WHEN EXISTS (
                    SELECT 1
                    FROM dbo.Sales
                    WHERE SalesNumber BETWEEN 90000 AND 99999
                      AND ISNULL(DocType, '') <> 'OB'
                ) THEN 1 ELSE 0 END;

            IF @HasReservedCollision = 1
                THROW 51010, 'Reserved opening AR SalesNumber range 90000-99999 already contains non-opening Sales rows.', 1;

            SELECT @NextSalesNumber =
                ISNULL(MAX(CASE
                    WHEN DocType = 'OB'
                     AND SalesNumber BETWEEN 90000 AND 99999
                    THEN SalesNumber
                END), 89999) + 1
            FROM dbo.Sales;

            IF @NextSalesNumber + ISNULL(@FilledARCount, 0) - 1 >= 100000
                THROW 51011, 'Reserved opening AR SalesNumber range 90000-99999 does not have enough remaining numbers.', 1;

            IF NOT EXISTS (
                SELECT 1
                FROM sys.check_constraints
                WHERE parent_object_id = OBJECT_ID('dbo.Sales')
                  AND name = 'CK_Sales_DocType'
                  AND definition LIKE '%''OB''%'
            )
                THROW 51012, 'Sales.DocType constraint does not allow OB. Deploy Slice 0 before importing AR opening balances.', 1;

            WITH Filled AS (
                SELECT
                    t.AutoId,
                    ROW_NUMBER() OVER (ORDER BY t.AutoId) AS FilledSeq,
                    NULLIF(LTRIM(RTRIM(t.CustomerName)), '') AS CustomerName,
                    NULLIF(LTRIM(RTRIM(t.InvoiceNumber)), '') AS InvoiceNumber,
                    NULLIF(LTRIM(RTRIM(t.InvoiceDateRaw)), '') AS InvoiceDateRaw,
                    t.Amount,
                    t.Notes,
                    t.PayeeId
                FROM @AR t
                WHERE t.Amount IS NOT NULL
            ),
            Parsed AS (
                SELECT
                    f.*,
                    @NextSalesNumber + f.FilledSeq - 1 AS SalesNumber,
                    CASE
                        WHEN f.InvoiceDateRaw IS NULL THEN CAST(NULL AS DATE)
                        WHEN f.InvoiceDateRaw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                         AND LEN(f.InvoiceDateRaw) = 10
                        THEN TRY_CONVERT(DATE, f.InvoiceDateRaw, 23)
                        WHEN (
                                f.InvoiceDateRaw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]%'
                             OR PATINDEX('%[A-Za-z]%', f.InvoiceDateRaw) > 0
                             )
                         AND TRY_CONVERT(DATE, f.InvoiceDateRaw) IS NOT NULL
                        THEN TRY_CONVERT(DATE, f.InvoiceDateRaw)
                        ELSE CAST(NULL AS DATE)
                    END AS ParsedInvoiceDate,
                    CASE
                        WHEN f.InvoiceDateRaw IS NULL THEN 1
                        WHEN f.InvoiceDateRaw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                         AND LEN(f.InvoiceDateRaw) = 10
                         AND TRY_CONVERT(DATE, f.InvoiceDateRaw, 23) IS NOT NULL
                        THEN 1
                        WHEN (
                                f.InvoiceDateRaw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]%'
                             OR PATINDEX('%[A-Za-z]%', f.InvoiceDateRaw) > 0
                             )
                         AND TRY_CONVERT(DATE, f.InvoiceDateRaw) IS NOT NULL
                        THEN 1
                        ELSE 0
                    END AS IsDateValid
                FROM Filled f
            )
            INSERT INTO @PreparedAR
                (RowNo, FilledSeq, CustomerName, InvoiceNumber, InvoiceDate, IsDateValid,
                 Amount, Notes, PayeeId, SalesNumber, SalesDocNumber)
            SELECT
                p.AutoId,
                p.FilledSeq,
                p.CustomerName,
                p.InvoiceNumber,
                p.ParsedInvoiceDate,
                p.IsDateValid,
                p.Amount,
                p.Notes,
                p.PayeeId,
                p.SalesNumber,
                COALESCE(CONVERT(NVARCHAR(50), p.InvoiceNumber),
                         CONCAT('OB-AR-', CONVERT(NVARCHAR(20), p.SalesNumber)))
            FROM Parsed p
            ORDER BY p.AutoId;

            IF EXISTS (SELECT 1 FROM @PreparedAR WHERE PayeeId IS NULL)
                THROW 51013, 'AR import contains a filled row with blank PayeeId.', 1;

            IF EXISTS (
                SELECT 1
                FROM @PreparedAR p
                LEFT JOIN dbo.Payee pay ON pay.PayeeId = p.PayeeId
                WHERE pay.PayeeId IS NULL
            )
                THROW 51014, 'AR import contains a PayeeId that does not exist.', 1;

            IF EXISTS (
                SELECT 1
                FROM @PreparedAR p
                LEFT JOIN dbo.Customer c ON c.PayeeId = p.PayeeId
                LEFT JOIN dbo.Payee pay ON pay.PayeeId = p.PayeeId
                -- 2026-08-05: IsClosed dropped from this check. The download returns
                -- existing rows for closed customers, so rejecting them here made the
                -- exported workbook impossible to re-import without deleting a real
                -- balance. Closed is now a preview warning. Type and existence are
                -- still enforced, and a closed payee cannot be newly selected because
                -- the blank starter rows filter on IsClosed = 0. Old code:
                --    OR pay.IsClosed = 1
                WHERE c.PayeeId IS NULL
                   OR ISNULL(pay.PayeeType, '') <> 'C'
            )
                THROW 51015, 'AR import contains a PayeeId that is not a customer.', 1;

            IF EXISTS (SELECT 1 FROM @PreparedAR WHERE IsDateValid = 0)
                THROW 51016, 'AR import contains an invalid InvoiceDate.', 1;

            IF EXISTS (SELECT 1 FROM @PreparedAR WHERE LEN(ISNULL(InvoiceNumber, '')) > 50)
                THROW 51017, 'AR import contains an InvoiceNumber longer than 50 characters.', 1;

            IF EXISTS (
                SELECT 1
                FROM @PreparedAR p
                WHERE p.InvoiceNumber IS NOT NULL
                  AND EXISTS (
                        SELECT 1
                        FROM @PreparedAR d
                        WHERE d.PayeeId = p.PayeeId
                          AND d.InvoiceNumber = p.InvoiceNumber
                        GROUP BY d.PayeeId, d.InvoiceNumber
                        HAVING COUNT(*) > 1
                  )
            )
                THROW 51018, 'AR import contains duplicate InvoiceNumber values for the same customer.', 1;

            IF EXISTS (
                SELECT 1
                FROM @PreparedAR p
                INNER JOIN dbo.Sales s
                    ON s.ShipId = p.PayeeId
                   AND s.SalesDocNumber = p.InvoiceNumber
                   AND ISNULL(s.DocType, '') <> 'OB'
                WHERE p.InvoiceNumber IS NOT NULL
            )
                THROW 51019, 'AR import contains an InvoiceNumber that already exists for the same customer.', 1;

            INSERT INTO @OldOBSales (SalesId, SalesNumber)
            SELECT DISTINCT s.SalesId, s.SalesNumber
            FROM dbo.OpenBalanceAR o
            INNER JOIN dbo.Sales s
                ON s.SalesId = o.SalesId
            WHERE s.DocType = 'OB';

            IF EXISTS (SELECT 1 FROM dbo.Purchase x INNER JOIN @OldOBSales o ON o.SalesId = x.DropShipSalesId)
                THROW 51020, 'Cannot replace AR opening balance because old OB Sales rows are linked to purchases.', 1;

            IF EXISTS (SELECT 1 FROM dbo.SalesDetail x INNER JOIN @OldOBSales o ON o.SalesId = x.SalesId)
                THROW 51021, 'Cannot replace AR opening balance because old OB Sales rows have sales detail rows.', 1;

            IF EXISTS (SELECT 1 FROM dbo.SalesQuote x INNER JOIN @OldOBSales o ON o.SalesId = x.SalesId)
                THROW 51022, 'Cannot replace AR opening balance because old OB Sales rows are linked to sales quotes.', 1;

            IF EXISTS (SELECT 1 FROM dbo.CustomerPayment x INNER JOIN @OldOBSales o ON o.SalesId = x.ReturnSalesId)
                THROW 51023, 'Cannot replace AR opening balance because old OB Sales rows are linked to customer payments.', 1;

            IF EXISTS (
                SELECT 1
                FROM dbo.CustomerPaymentDetail x
                INNER JOIN @OldOBSales o
                    ON o.SalesId = x.SalesId
                    OR o.SalesId = x.SourceSalesId
            )
                THROW 51024, 'Cannot replace AR opening balance because old OB Sales rows have payment applications.', 1;

            IF EXISTS (SELECT 1 FROM dbo.SalesRouteDetail x INNER JOIN @OldOBSales o ON o.SalesId = x.CreditMemoSalesId)
                THROW 51025, 'Cannot replace AR opening balance because old OB Sales rows are linked to route credit memos.', 1;

            IF EXISTS (SELECT 1 FROM dbo.TempBombSales x INNER JOIN @OldOBSales o ON o.SalesId = x.SalesId)
                THROW 51026, 'Cannot replace AR opening balance because old OB Sales rows are linked to temp bomb sales.', 1;

            IF EXISTS (SELECT 1 FROM dbo.TempCustomerPayment x INNER JOIN @OldOBSales o ON o.SalesId = x.SalesId)
                THROW 51027, 'Cannot replace AR opening balance because old OB Sales rows are linked to temp customer payments.', 1;

            IF EXISTS (
                SELECT 1
                FROM dbo.TempSales x
                INNER JOIN @OldOBSales o
                    ON o.SalesId = x.SalesId
                    OR o.SalesNumber = x.ParentSalesNumber
            )
                THROW 51028, 'Cannot replace AR opening balance because old OB Sales rows are linked to temp sales.', 1;

            IF EXISTS (
                SELECT 1
                FROM dbo.TransactionJournal x
                INNER JOIN @OldOBSales o
                    ON o.SalesNumber = x.SourceDocNumber
                WHERE ISNULL(x.SourceDocType, '') <> 'General Journal'
            )
                THROW 51029, 'Cannot replace AR opening balance because old OB Sales rows have non-opening transaction journals.', 1;

            EXEC dbo.OpenBalance_Unpost @Section = 'AR';

            DELETE FROM dbo.OpenBalanceAR;

            DELETE s
            FROM dbo.Sales s
            INNER JOIN @OldOBSales o
                ON o.SalesId = s.SalesId
            WHERE s.DocType = 'OB';

            INSERT INTO dbo.Sales
                (SalesNumber, StageId, SalesDate, ShipDate, ShipId, BillId, SalesRepId, TermId,
                 SubTotal, DiscountTotal, TaxableTotal, TaxPercent, TaxTotal, SalesTotal, AmountDue,
                 PaymentApplied, DiscountApplied, Instruction, ShippingCarrierId,
                 IsLoadSeparate, IsLocked, IsStatementAttached, IsDropShip,
                 CreatedAt, DocType, SalesDocNumber)
            OUTPUT INSERTED.SalesId, INSERTED.SalesNumber
            INTO @InsertedSales (SalesId, SalesNumber)
            SELECT
                p.SalesNumber,
                4,
                CONVERT(DATETIME, ISNULL(p.InvoiceDate, @AsOfDate)),
                ISNULL(p.InvoiceDate, @AsOfDate),
                p.PayeeId,
                c.BillId,
                c.SalesRepId,
                pay.TermId,
                p.Amount,
                0,
                0,
                ISNULL(c.TaxRate, 0),
                0,
                p.Amount,
                p.Amount,
                0,
                0,
                LEFT(CONCAT('Opening AR import', CASE WHEN p.Notes IS NULL THEN '' ELSE ': ' + p.Notes END), 300),
                c.ShippingCarrierId,
                0,
                0,
                0,
                0,
                GETUTCDATE(),
                'OB',
                p.SalesDocNumber
            FROM @PreparedAR p
            INNER JOIN dbo.Customer c
                ON c.PayeeId = p.PayeeId
            INNER JOIN dbo.Payee pay
                ON pay.PayeeId = p.PayeeId
            ORDER BY p.RowNo;

            INSERT INTO dbo.OpenBalanceAR
                (SalesId, SalesNum, PayeeId, AsOfDate, Amount, Notes, CreatedAt)
            SELECT
                i.SalesId,
                -- 2026-08-05: SalesNum now stores the client's own invoice number from
                -- their previous system, as text, and NULL when they left it blank.
                -- SalesId is the link to our Sales row, so SalesNum no longer needs to
                -- repeat our generated number. The OB-AR-<SalesNumber> fallback stays on
                -- Sales.SalesDocNumber only: SalesNum means "what the client typed".
                -- Old code:
                -- p.SalesNumber,
                p.InvoiceNumber,
                p.PayeeId,
                @AsOfDate,
                p.Amount,
                p.Notes,
                GETUTCDATE()
            FROM @PreparedAR p
            INNER JOIN @InsertedSales i
                ON i.SalesNumber = p.SalesNumber
            ORDER BY p.RowNo;

            SET @RowCount = @@ROWCOUNT;
        END

        ------------------------------------------------------------------
        -- AP
        ------------------------------------------------------------------
        -- 2026-08-05: rewritten for the name-first AP template. Creates one
        -- Purchase header per bill, links OpenBalanceAP to it, and posts under
        -- GJNum -2. Deliberately does NOT call Purchase_Insert: these are
        -- header-only opening records and must not run normal purchase posting.
        ELSE IF @Sec = 'AP'
        BEGIN
            DECLARE @AP AS TABLE (
                AutoId       INT IDENTITY(1,1),
                VendorName   NVARCHAR(255)   NULL,
                BillNumber   NVARCHAR(200)   NULL,
                BillDateRaw  NVARCHAR(100)   NULL,
                Amount       DECIMAL(18,2)   NULL,
                Notes        NVARCHAR(400)   NULL,
                PayeeId      INT             NULL
            );

            DECLARE @PreparedAP AS TABLE (
                RowNo            INT             NOT NULL,
                FilledSeq        INT             NOT NULL,
                VendorName       NVARCHAR(255)   NULL,
                BillNumber       NVARCHAR(200)   NULL,
                BillDate         DATE            NULL,
                IsDateValid      BIT             NOT NULL,
                Amount           DECIMAL(18,2)   NOT NULL,
                Notes            NVARCHAR(400)   NULL,
                PayeeId          INT             NULL,
                PurchaseNumber   INT             NULL,
                VendorDocNumber  NVARCHAR(200)   NULL
            );

            -- Only opening purchases this import created can be replaced.
            -- Adopted legacy bills sit outside the reserved block, are already
            -- paid, and are left alone (D12 option i).
            DECLARE @ReplaceableOB AS TABLE (
                PurchaseId     INT NOT NULL PRIMARY KEY,
                PurchaseNumber INT NOT NULL
            );

            DECLARE @InsertedPurchase AS TABLE (
                PurchaseId     INT NOT NULL,
                PurchaseNumber INT NOT NULL
            );

            SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [AP$]);';

            INSERT INTO @AP EXEC (@Qry);

            SELECT @PriorRowCount = COUNT(*) FROM dbo.OpenBalanceAP;

            DECLARE @FilledAPCount INT;
            DECLARE @NextPurchaseNumber INT;

            SELECT @FilledAPCount = COUNT(*)
            FROM @AP
            WHERE Amount IS NOT NULL;

            IF EXISTS (
                SELECT 1
                FROM dbo.Purchase p
                WHERE p.PurchaseNumber BETWEEN 50001 AND 59999
                  AND NOT EXISTS (
                        SELECT 1
                        FROM dbo.OpenBalanceAP o
                        WHERE o.PurchaseId = p.PurchaseId
                  )
            )
                THROW 51040, 'Reserved opening AP PurchaseNumber range 50001-59999 already contains purchases that are not opening-balance rows.', 1;

            SELECT @NextPurchaseNumber =
                ISNULL(MAX(CASE
                    WHEN p.PurchaseNumber BETWEEN 50001 AND 59999
                    THEN p.PurchaseNumber
                END), 50000) + 1
            FROM dbo.Purchase p
            INNER JOIN dbo.OpenBalanceAP o
                ON o.PurchaseId = p.PurchaseId;

            IF @NextPurchaseNumber + ISNULL(@FilledAPCount, 0) - 1 >= 60000
                THROW 51041, 'Reserved opening AP PurchaseNumber range 50001-59999 does not have enough remaining numbers.', 1;

            ;WITH Filled AS (
                SELECT
                    t.AutoId,
                    ROW_NUMBER() OVER (ORDER BY t.AutoId) AS FilledSeq,
                    NULLIF(LTRIM(RTRIM(t.VendorName)), '')  AS VendorName,
                    NULLIF(LTRIM(RTRIM(t.BillNumber)), '')  AS BillNumber,
                    NULLIF(LTRIM(RTRIM(t.BillDateRaw)), '') AS BillDateRaw,
                    t.Amount,
                    t.Notes,
                    t.PayeeId
                FROM @AP t
                WHERE t.Amount IS NOT NULL
            ),
            Parsed AS (
                SELECT
                    f.*,
                    @NextPurchaseNumber + f.FilledSeq - 1 AS PurchaseNumber,
                    CASE
                        WHEN f.BillDateRaw IS NULL THEN CAST(NULL AS DATE)
                        WHEN f.BillDateRaw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                         AND LEN(f.BillDateRaw) = 10
                        THEN TRY_CONVERT(DATE, f.BillDateRaw, 23)
                        WHEN (
                                f.BillDateRaw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]%'
                             OR PATINDEX('%[A-Za-z]%', f.BillDateRaw) > 0
                             )
                         AND TRY_CONVERT(DATE, f.BillDateRaw) IS NOT NULL
                        THEN TRY_CONVERT(DATE, f.BillDateRaw)
                        ELSE CAST(NULL AS DATE)
                    END AS ParsedBillDate,
                    CASE
                        WHEN f.BillDateRaw IS NULL THEN 1
                        WHEN f.BillDateRaw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                         AND LEN(f.BillDateRaw) = 10
                         AND TRY_CONVERT(DATE, f.BillDateRaw, 23) IS NOT NULL
                        THEN 1
                        WHEN (
                                f.BillDateRaw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]%'
                             OR PATINDEX('%[A-Za-z]%', f.BillDateRaw) > 0
                             )
                         AND TRY_CONVERT(DATE, f.BillDateRaw) IS NOT NULL
                        THEN 1
                        ELSE 0
                    END AS IsDateValid
                FROM Filled f
            )
            INSERT INTO @PreparedAP
                (RowNo, FilledSeq, VendorName, BillNumber, BillDate, IsDateValid,
                 Amount, Notes, PayeeId, PurchaseNumber, VendorDocNumber)
            SELECT
                p.AutoId,
                p.FilledSeq,
                p.VendorName,
                p.BillNumber,
                p.ParsedBillDate,
                p.IsDateValid,
                p.Amount,
                p.Notes,
                p.PayeeId,
                p.PurchaseNumber,
                COALESCE(p.BillNumber,
                         CONCAT('OB-AP-', CONVERT(NVARCHAR(20), p.PurchaseNumber)))
            FROM Parsed p
            ORDER BY p.AutoId;

            ------------------------------------------------------------------
            -- Validation. Mirrors OpenBalance_ImportPreview so a file that
            -- previewed clean cannot fail halfway through the write.
            ------------------------------------------------------------------

            IF EXISTS (SELECT 1 FROM @PreparedAP WHERE PayeeId IS NULL)
                THROW 51042, 'AP import contains a filled row with blank PayeeId.', 1;

            IF EXISTS (
                SELECT 1
                FROM @PreparedAP p
                LEFT JOIN dbo.Payee pay ON pay.PayeeId = p.PayeeId
                WHERE pay.PayeeId IS NULL
            )
                THROW 51043, 'AP import contains a PayeeId that does not exist.', 1;

            IF EXISTS (
                SELECT 1
                FROM @PreparedAP p
                LEFT JOIN dbo.Vendor v   ON v.PayeeId = p.PayeeId
                LEFT JOIN dbo.Payee pay  ON pay.PayeeId = p.PayeeId
                -- 2026-08-05: IsClosed dropped here too; same reasoning as AR above.
                WHERE v.PayeeId IS NULL
                   OR ISNULL(pay.PayeeType, '') <> 'V'
            )
                THROW 51044, 'AP import contains a PayeeId that is not a vendor.', 1;

            IF EXISTS (SELECT 1 FROM @PreparedAP WHERE IsDateValid = 0)
                THROW 51045, 'AP import contains an invalid BillDate. Use yyyy-MM-dd or leave it blank.', 1;

            IF EXISTS (SELECT 1 FROM @PreparedAP WHERE LEN(ISNULL(BillNumber, '')) > 200)
                THROW 51046, 'AP import contains a BillNumber longer than 200 characters.', 1;

            IF EXISTS (
                SELECT 1
                FROM @PreparedAP p
                WHERE p.BillNumber IS NOT NULL
                  AND EXISTS (
                        SELECT 1
                        FROM @PreparedAP d
                        WHERE d.PayeeId = p.PayeeId
                          AND d.BillNumber = p.BillNumber
                        GROUP BY d.PayeeId, d.BillNumber
                        HAVING COUNT(*) > 1
                  )
            )
                THROW 51047, 'AP import contains duplicate BillNumber values for the same vendor.', 1;

            -- Opening purchases, including the adopted legacy ones, are exempt:
            -- they are what this section owns.
            IF EXISTS (
                SELECT 1
                FROM @PreparedAP p
                INNER JOIN dbo.Purchase pu
                    ON pu.PayeeId = p.PayeeId
                   AND pu.VendorDocNumber = p.BillNumber
                WHERE p.BillNumber IS NOT NULL
                  AND NOT EXISTS (
                        SELECT 1
                        FROM dbo.OpenBalanceAP o
                        WHERE o.PurchaseId = pu.PurchaseId
                  )
            )
                THROW 51048, 'AP import contains a BillNumber that already exists for the same vendor on a purchase that is not an opening balance.', 1;

            ------------------------------------------------------------------
            -- Replacement safety. Only opening purchases inside the reserved
            -- block are candidates for deletion.
            ------------------------------------------------------------------

            INSERT INTO @ReplaceableOB (PurchaseId, PurchaseNumber)
            SELECT DISTINCT pu.PurchaseId, pu.PurchaseNumber
            FROM dbo.OpenBalanceAP o
            INNER JOIN dbo.Purchase pu
                ON pu.PurchaseId = o.PurchaseId
            WHERE pu.PurchaseNumber BETWEEN 50001 AND 59999;

            IF EXISTS (SELECT 1 FROM dbo.PurchaseDetail x INNER JOIN @ReplaceableOB r ON r.PurchaseId = x.PurchaseId)
                THROW 51049, 'Cannot replace AP opening balance because old opening purchases have detail rows.', 1;

            IF EXISTS (SELECT 1 FROM dbo.VendorPaymentDetail x INNER JOIN @ReplaceableOB r ON r.PurchaseId = x.PurchaseId)
                THROW 51050, 'Cannot replace AP opening balance because vendor payments have been applied to old opening bills.', 1;

            IF EXISTS (SELECT 1 FROM dbo.TempVendorPayment x INNER JOIN @ReplaceableOB r ON r.PurchaseId = x.PurchaseId)
                THROW 51051, 'Cannot replace AP opening balance because old opening bills are in a vendor payment cart.', 1;

            IF EXISTS (SELECT 1 FROM dbo.ShipmentPurchase x INNER JOIN @ReplaceableOB r ON r.PurchaseId = x.PurchaseId)
                THROW 51052, 'Cannot replace AP opening balance because old opening bills are linked to shipments.', 1;

            IF EXISTS (SELECT 1 FROM dbo.ShipmentChargeBill x INNER JOIN @ReplaceableOB r ON r.PurchaseId = x.PurchaseId)
                THROW 51053, 'Cannot replace AP opening balance because old opening bills are linked to shipment charges.', 1;

            IF EXISTS (SELECT 1 FROM dbo.FreightBillLink x INNER JOIN @ReplaceableOB r ON r.PurchaseId = x.PurchaseId)
                THROW 51054, 'Cannot replace AP opening balance because old opening bills are linked to freight bills.', 1;

            IF EXISTS (SELECT 1 FROM dbo.PurchaseOrder x INNER JOIN @ReplaceableOB r ON r.PurchaseId = x.PurchaseId)
                THROW 51055, 'Cannot replace AP opening balance because old opening bills are linked to purchase orders.', 1;

            IF EXISTS (SELECT 1 FROM dbo.TempPurchase x INNER JOIN @ReplaceableOB r ON r.PurchaseId = x.PurchaseId)
                THROW 51056, 'Cannot replace AP opening balance because old opening bills are open in a purchase edit.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Sales x INNER JOIN @ReplaceableOB r ON r.PurchaseId = x.DropShipPurchaseId)
                THROW 51057, 'Cannot replace AP opening balance because old opening bills are linked to drop-ship sales.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Purchase x INNER JOIN @ReplaceableOB r ON r.PurchaseId = x.SourcePurchaseId)
                THROW 51058, 'Cannot replace AP opening balance because old opening bills are the source of another purchase.', 1;

            IF EXISTS (
                SELECT 1
                FROM dbo.TransactionJournal x
                INNER JOIN @ReplaceableOB r
                    ON r.PurchaseNumber = x.SourceDocNumber
                WHERE ISNULL(x.SourceDocType, '') <> 'General Journal'
            )
                THROW 51059, 'Cannot replace AP opening balance because old opening bills have non-opening transaction journals.', 1;

            ------------------------------------------------------------------
            -- Replace. Adopted rows and their staging rows are untouched.
            ------------------------------------------------------------------

            EXEC dbo.OpenBalance_Unpost @Section = 'AP';

            -- Everything except adopted rows: unlinked staging rows and rows
            -- whose purchase this import created.
            DELETE o
            FROM dbo.OpenBalanceAP o
            LEFT JOIN dbo.Purchase pu
                ON pu.PurchaseId = o.PurchaseId
            WHERE pu.PurchaseId IS NULL
               OR pu.PurchaseNumber BETWEEN 50001 AND 59999;

            -- Goes through TRG_Delete_PurchaseTx, an INSTEAD OF trigger, so no
            -- row-count assertion belongs here.
            DELETE pu
            FROM dbo.Purchase pu
            INNER JOIN @ReplaceableOB r
                ON r.PurchaseId = pu.PurchaseId;

            INSERT INTO dbo.Purchase
                (PurchaseNumber, StageId, PayeeId, PurchaseDate, EnterDate, ArrivalDate,
                 InvoiceDate, VendorDocNumber, TermId, VendorTotal, PurchaseTotal, AmountDue,
                 PaymentApplied, DiscountApplied, Notes,
                 IsLocked, IsStartFromPO, IsShipment, IsFreightOnly, IsDropShip, CreatedAt)
            OUTPUT INSERTED.PurchaseId, INSERTED.PurchaseNumber
            INTO @InsertedPurchase (PurchaseId, PurchaseNumber)
            SELECT
                p.PurchaseNumber,
                6,                                          -- Billed; required for AP aging
                p.PayeeId,
                ISNULL(p.BillDate, @AsOfDate),
                @AsOfDate,
                ISNULL(p.BillDate, @AsOfDate),
                ISNULL(p.BillDate, @AsOfDate),
                p.VendorDocNumber,
                pay.TermId,
                p.Amount,
                p.Amount,
                p.Amount,
                0,
                0,
                LEFT(CONCAT('Opening AP import', CASE WHEN p.Notes IS NULL THEN '' ELSE ': ' + p.Notes END), 1000),
                0, 0, 0, 0, 0,
                GETUTCDATE()
            FROM @PreparedAP p
            INNER JOIN dbo.Payee pay
                ON pay.PayeeId = p.PayeeId
            ORDER BY p.RowNo;

            INSERT INTO dbo.OpenBalanceAP
                (PurchaseId, PurchaseNum, PayeeId, AsOfDate, Amount, Notes, CreatedAt)
            SELECT
                i.PurchaseId,
                p.BillNumber,           -- what the client typed, NULL when blank
                p.PayeeId,
                @AsOfDate,
                p.Amount,
                p.Notes,
                GETUTCDATE()
            FROM @PreparedAP p
            INNER JOIN @InsertedPurchase i
                ON i.PurchaseNumber = p.PurchaseNumber
            ORDER BY p.RowNo;

            SET @RowCount = @@ROWCOUNT;
        END

        ------------------------------------------------------------------
        -- ARE
        ------------------------------------------------------------------
        ELSE IF @Sec = 'ARE'
        BEGIN
            DECLARE @ARE AS TABLE (
                AutoId       INT IDENTITY(1,1),
                PayeeId      INT            NULL,
                EmployeeName NVARCHAR(255)  NULL,
                Amount       DECIMAL(18,2)  NULL,
                Notes        NVARCHAR(400)  NULL
            );

            SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [ARE$]);';

            INSERT INTO @ARE EXEC (@Qry);

            SELECT @PriorRowCount = COUNT(*) FROM dbo.OpenBalanceARE;

            DELETE FROM dbo.OpenBalanceARE;

            INSERT INTO dbo.OpenBalanceARE
                (PayeeId, AsOfDate, Amount, Notes, CreatedAt)
            SELECT
                t.PayeeId,
                @AsOfDate,
                ISNULL(t.Amount, 0),
                t.Notes,
                GETUTCDATE()
            FROM @ARE t
            WHERE t.Amount IS NOT NULL
            ORDER BY t.AutoId;

            SET @RowCount = @@ROWCOUNT;
        END

        ------------------------------------------------------------------
        -- INV
        ------------------------------------------------------------------
        ELSE IF @Sec = 'INV'
        BEGIN
            DECLARE @Inv AS TABLE (
                AutoId     INT IDENTITY(1,1),
                ItemCode   NVARCHAR(100)  NULL,
                ItemName   NVARCHAR(255)  NULL,
                Qty        DECIMAL(18,4)  NULL,
                Price      DECIMAL(18,4)  NULL,
                TotalValue DECIMAL(18,2)  NULL,
                Notes      NVARCHAR(400)  NULL
            );

            SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [Inventory$]);';

            INSERT INTO @Inv EXEC (@Qry);

            SELECT @PriorRowCount = COUNT(*) FROM dbo.OpenBalanceInv;

            DELETE FROM dbo.OpenBalanceInv;

            INSERT INTO dbo.OpenBalanceInv
                (ItemId, ItemCode, AsOfDate, Qty, Price, TotalValue, Notes, CreatedAt)
            SELECT
                i.ItemId,
                t.ItemCode,
                @AsOfDate,
                t.Qty,
                t.Price,
                t.TotalValue,
                t.Notes,
                GETUTCDATE()
            FROM @Inv t
            CROSS APPLY (
                SELECT MIN(x.ItemId) AS ItemId
                FROM dbo.Item x
                WHERE x.ItemCode = t.ItemCode
            ) i
            WHERE NOT (t.Qty IS NULL AND t.Price IS NULL AND t.TotalValue IS NULL)
            ORDER BY t.AutoId;

            SET @RowCount = @@ROWCOUNT;
        END

        ------------------------------------------------------------------
        -- Post. Same transaction, so a failure here takes the saved rows
        -- down with it.
        ------------------------------------------------------------------
        EXEC dbo.OpenBalance_Post @Section = @Sec;

    COMMIT;
END

GO
