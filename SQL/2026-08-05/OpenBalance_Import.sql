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
                WHERE c.PayeeId IS NULL
                   OR ISNULL(pay.PayeeType, '') <> 'C'
                   OR pay.IsClosed = 1
            )
                THROW 51015, 'AR import contains a PayeeId that is not an active customer.', 1;

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
                p.SalesNumber,
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
        ELSE IF @Sec = 'AP'
        BEGIN
            DECLARE @AP AS TABLE (
                AutoId      INT IDENTITY(1,1),
                PayeeId     INT             NULL,
                VendorName  NVARCHAR(255)   NULL,
                BillNumber  NVARCHAR(100)   NULL,
                Amount      DECIMAL(18,2)   NULL,
                Notes       NVARCHAR(400)   NULL
            );

            SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [AP$]);';

            INSERT INTO @AP EXEC (@Qry);

            SELECT @PriorRowCount = COUNT(*) FROM dbo.OpenBalanceAP;

            DELETE FROM dbo.OpenBalanceAP;

            INSERT INTO dbo.OpenBalanceAP
                (PurchaseId, PurchaseNum, PayeeId, AsOfDate, Amount, Notes, CreatedAt)
            SELECT
                NULL,
                TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(t.BillNumber)), '')),
                t.PayeeId,
                @AsOfDate,
                ISNULL(t.Amount, 0),
                t.Notes,
                GETUTCDATE()
            FROM @AP t
            WHERE t.Amount IS NOT NULL
            ORDER BY t.AutoId;

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
