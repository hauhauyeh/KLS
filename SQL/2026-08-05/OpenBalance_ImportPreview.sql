SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- ============================================================
-- OpenBalance_ImportPreview
-- 2026-08-04: NEW. Read-only companion to OpenBalance_Import.
-- 2026-08-04: Blank seeded rows are ignored, counted in
-- @IgnoredRowCount, and excluded from this result set. The predicates
-- must stay identical to OpenBalance_Import.
-- Parses ONE section's workbook and returns one row per Excel row,
-- enriched with the database values the importer will actually use and
-- a severity the screen can act on. Writes nothing.
--
-- Why a stored procedure and not ClosedXML in .NET: the parse is done
-- by SQL Server via the ACE OLEDB provider. Previewing in .NET and
-- importing via OPENROWSET would let the two disagree -- most
-- dangerously on ACE's type sniffing, which infers a column's type from
-- the first 8 rows. This proc runs the IDENTICAL OPENROWSET statement
-- against the IDENTICAL table-variable shape as the importer, so what
-- the user approves is what gets loaded. Same discipline as
-- VendorPayment_ImportPreview.
--
-- IMEX=1 IS REQUIRED, NOT DECORATION. Every one of the 1,858 current
-- OpenBalanceInv.Notes values is blank, so without IMEX=1 ACE types
-- that column from eight empty cells and silently returns NULL for any
-- note a user adds further down the sheet. It must stay byte-identical
-- with the string in OpenBalance_Import.
--
-- @Section picks a hard-coded branch. The sheet name is a LITERAL in
-- each branch and is never concatenated from input; only @FilePath is
-- concatenated, and the caller guarantees it is <guid>.xlsx.
--
-- Severity vocabulary (see the plan, section 6.2):
--   Error    import impossible          button disabled, no override
--   Confirm  possible, probably wrong   button disabled until ticked
--   Warning  proceeds; user should know
--   Info     neutral fact about a row
--   OK       nothing to say
-- Confirm is decided in the service, not here: it needs the prior row
-- count and the download stamp, which are not row-level facts.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[OpenBalance_ImportPreview]
    -- EXEC dbo.OpenBalance_ImportPreview @FilePath = 'C:\...\abc.xlsx', @Section = 'AR'

    @FilePath       NVARCHAR(255),
    @Section        NVARCHAR(20),
    @DownloadedAt     DATETIME OUTPUT,
    @IgnoredRowCount  INT = 0 OUTPUT

AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Sec  NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@Section, ''))));
    DECLARE @Qry  NVARCHAR(MAX);
    DECLARE @Msg  NVARCHAR(400);

    SET @DownloadedAt = NULL;
    SET @IgnoredRowCount = 0;

    IF @Sec NOT IN ('ACCOUNT', 'AR', 'AP', 'INV', 'ARE')
    BEGIN
        SET @Msg = CONCAT(
            'Unknown opening balance section "', ISNULL(@Section, '<null>'),
            '". Expected ACCOUNT, AR, AP, INV or ARE.');

        THROW 51000, @Msg, 1;
    END

    ------------------------------------------------------------------
    -- Download stamp, from the Instructions sheet.
    -- A hand-built workbook has no Instructions sheet and no stamp.
    -- That is legitimate input: leave @DownloadedAt NULL and say
    -- nothing. Never reject a file for lacking a field only our own
    -- generator writes.
    ------------------------------------------------------------------
    BEGIN TRY
        DECLARE @Instructions AS TABLE (
            [Field] NVARCHAR(100) NULL,
            [Value] NVARCHAR(400) NULL
        );

        SET @Qry = 'SELECT [Field],[Value] FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [Instructions$]);';

        INSERT INTO @Instructions
        EXEC (@Qry);

        SELECT @DownloadedAt = TRY_CONVERT(DATETIME, [Value])
        FROM @Instructions
        WHERE [Field] = 'DownloadedAt';
    END TRY
    BEGIN CATCH
        SET @DownloadedAt = NULL;
    END CATCH

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

        BEGIN TRY
            SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [Account$]);';

            INSERT INTO @Account
            EXEC (@Qry);
        END TRY
        BEGIN CATCH
            SET @Msg = CONCAT(
                'Could not read an [Account] sheet from this workbook. Check that you picked the '
              + 'right section and that the file is the downloaded Account workbook. (',
                ERROR_MESSAGE(), ')');

            THROW 51001, @Msg, 1;
        END CATCH

        SELECT @IgnoredRowCount = COUNT(*)
        FROM @Account
        WHERE Balance IS NULL;

        SELECT
            t.AutoId                                            AS RowNo,
            t.AccountCode                                       AS Key1,
            CAST(NULL AS NVARCHAR(200))                         AS Key2,
            CAST(NULL AS DATE)                                  AS DocumentDate,
            a.AccountId                                         AS ResolvedId,
            a.AccountName                                       AS ResolvedName,
            CAST(NULL AS DECIMAL(18,4))                         AS Qty,
            CAST(NULL AS DECIMAL(18,4))                         AS Price,
            t.Balance                                           AS Amount,
            t.Notes                                             AS Notes,

            CASE
                WHEN NULLIF(LTRIM(RTRIM(t.AccountCode)), '') IS NULL         THEN 'Error'
                WHEN a.MatchCount = 0                                        THEN 'Error'
                WHEN a.MatchCount > 1                                        THEN 'Error'
                WHEN t.AccountCode = '@OBE'                                  THEN 'Error'
                WHEN d.DupCount > 1                                          THEN 'Error'
                WHEN t.Balance IS NULL                                       THEN 'Error'
                WHEN t.AccountCode IN ('@AR', '@AP', '@INV', '@ARE')         THEN 'Info'
                ELSE 'OK'
            END                                                 AS Severity,

            CASE
                WHEN NULLIF(LTRIM(RTRIM(t.AccountCode)), '') IS NULL
                    THEN 'Account code is required.'
                WHEN a.MatchCount = 0
                    THEN CONCAT('Account code "', t.AccountCode, '" does not exist.')
                WHEN a.MatchCount > 1
                    THEN CONCAT('Account code "', t.AccountCode, '" matches ', a.MatchCount, ' accounts.')
                WHEN t.AccountCode = '@OBE'
                    THEN 'Opening Balance Equity is calculated by the system and cannot be imported.'
                WHEN d.DupCount > 1
                    THEN CONCAT('Account code "', t.AccountCode, '" appears ', d.DupCount, ' times in this sheet.')
                WHEN t.Balance IS NULL
                    THEN 'Balance is required.'
                WHEN t.AccountCode IN ('@AR', '@AP', '@INV', '@ARE')
                    THEN 'Check figure only. This balance is compared against the matching section, never posted to this account.'
                ELSE NULL
            END                                                 AS [Message]

        FROM @Account t

        -- CROSS APPLY, not a JOIN: a duplicate AccountCode in the Account
        -- table would otherwise fan this preview out into extra rows and
        -- hide the real problem.
        CROSS APPLY (
            SELECT COUNT(*)         AS MatchCount,
                   MIN(x.AccountId) AS AccountId,
                   MIN(x.AccountName) AS AccountName
            FROM dbo.Account x
            WHERE x.AccountCode = t.AccountCode
        ) a

        CROSS APPLY (
            SELECT COUNT(*) AS DupCount
            FROM @Account y
            WHERE y.AccountCode = t.AccountCode
              AND y.Balance IS NOT NULL
        ) d

        WHERE t.Balance IS NOT NULL

        ORDER BY t.AutoId;
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

        BEGIN TRY
            SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [AR$]);';

            INSERT INTO @AR EXEC (@Qry);
        END TRY
        BEGIN CATCH
            SET @Msg = CONCAT(
                'Could not read an [AR] sheet from this workbook. Check that you picked '
              + 'the right section and that the file is the downloaded AR workbook. (',
                ERROR_MESSAGE(), ')');

            THROW 51001, @Msg, 1;
        END CATCH

        SELECT @IgnoredRowCount = COUNT(*)
        FROM @AR
        WHERE Amount IS NULL;

        DECLARE @FilledARCount INT;
        DECLARE @NextSalesNumber INT;
        DECLARE @HasReservedCollision BIT = 0;
        DECLARE @ReservedRangeExhausted BIT = 0;

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

        SELECT @NextSalesNumber =
            ISNULL(MAX(CASE
                WHEN DocType = 'OB'
                 AND SalesNumber BETWEEN 90000 AND 99999
                THEN SalesNumber
            END), 89999) + 1
        FROM dbo.Sales;

        IF @NextSalesNumber + ISNULL(@FilledARCount, 0) - 1 >= 100000
            SET @ReservedRangeExhausted = 1;

        WITH Filled AS (
            SELECT
                t.*,
                ROW_NUMBER() OVER (ORDER BY t.AutoId) AS FilledSeq,
                NULLIF(LTRIM(RTRIM(t.CustomerName)), '') AS CleanCustomerName,
                NULLIF(LTRIM(RTRIM(t.InvoiceNumber)), '') AS CleanInvoiceNumber,
                NULLIF(LTRIM(RTRIM(t.InvoiceDateRaw)), '') AS CleanInvoiceDateRaw
            FROM @AR t
            WHERE t.Amount IS NOT NULL
        ),
        Parsed AS (
            SELECT
                f.*,
                @NextSalesNumber + f.FilledSeq - 1 AS PreviewSalesNumber,
                CASE
                    WHEN f.CleanInvoiceDateRaw IS NULL THEN CAST(NULL AS DATE)
                    WHEN f.CleanInvoiceDateRaw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                     AND LEN(f.CleanInvoiceDateRaw) = 10
                    THEN TRY_CONVERT(DATE, f.CleanInvoiceDateRaw, 23)
                    WHEN (
                            f.CleanInvoiceDateRaw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]%'
                         OR PATINDEX('%[A-Za-z]%', f.CleanInvoiceDateRaw) > 0
                         )
                     AND TRY_CONVERT(DATE, f.CleanInvoiceDateRaw) IS NOT NULL
                    THEN TRY_CONVERT(DATE, f.CleanInvoiceDateRaw)
                    ELSE CAST(NULL AS DATE)
                END AS ParsedInvoiceDate,
                CASE
                    WHEN f.CleanInvoiceDateRaw IS NULL THEN 1
                    WHEN f.CleanInvoiceDateRaw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                     AND LEN(f.CleanInvoiceDateRaw) = 10
                     AND TRY_CONVERT(DATE, f.CleanInvoiceDateRaw, 23) IS NOT NULL
                    THEN 1
                    WHEN (
                            f.CleanInvoiceDateRaw LIKE '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]%'
                         OR PATINDEX('%[A-Za-z]%', f.CleanInvoiceDateRaw) > 0
                         )
                     AND TRY_CONVERT(DATE, f.CleanInvoiceDateRaw) IS NOT NULL
                    THEN 1
                    ELSE 0
                END AS IsInvoiceDateValid
            FROM Filled f
        )
        SELECT
            p.AutoId                                            AS RowNo,
            CAST(p.PayeeId AS NVARCHAR(200))                    AS Key1,
            COALESCE(p.CleanInvoiceNumber,
                     CONCAT('OB-AR-', CONVERT(NVARCHAR(20), p.PreviewSalesNumber))) AS Key2,
            p.ParsedInvoiceDate                                 AS DocumentDate,
            pay.PayeeId                                         AS ResolvedId,
            pay.PayeeName                                       AS ResolvedName,
            CAST(NULL AS DECIMAL(18,4))                         AS Qty,
            CAST(NULL AS DECIMAL(18,4))                         AS Price,
            p.Amount                                            AS Amount,
            p.Notes                                             AS Notes,

            CASE
                WHEN @HasReservedCollision = 1                  THEN 'Error'
                WHEN @ReservedRangeExhausted = 1                THEN 'Error'
                WHEN p.PayeeId IS NULL                          THEN 'Error'
                WHEN pay.PayeeId IS NULL                        THEN 'Error'
                WHEN c.PayeeId IS NULL                          THEN 'Error'
                WHEN ISNULL(pay.PayeeType, '') <> 'C'           THEN 'Error'
                WHEN pay.IsClosed = 1                           THEN 'Error'
                WHEN p.IsInvoiceDateValid = 0                   THEN 'Error'
                WHEN LEN(ISNULL(p.CleanInvoiceNumber, '')) > 50 THEN 'Error'
                WHEN d.DupCount > 1                             THEN 'Error'
                WHEN ex.SalesId IS NOT NULL                     THEN 'Error'
                WHEN ISNULL(p.CleanCustomerName, '') <> ISNULL(pay.PayeeName, '')
                                                                THEN 'Warning'
                WHEN n.PayeeNet = 0                             THEN 'Warning'
                ELSE 'OK'
            END                                                 AS Severity,

            CASE
                WHEN @HasReservedCollision = 1
                    THEN 'Reserved opening AR SalesNumber range 90000-99999 already contains non-opening Sales rows.'
                WHEN @ReservedRangeExhausted = 1
                    THEN 'Reserved opening AR SalesNumber range 90000-99999 does not have enough remaining numbers.'
                WHEN p.PayeeId IS NULL
                    THEN 'Payee ID is required.'
                WHEN pay.PayeeId IS NULL
                    THEN CONCAT('Payee ID ', p.PayeeId, ' does not exist.')
                WHEN c.PayeeId IS NULL
                    THEN CONCAT('Payee ID ', p.PayeeId, ' is not a customer.')
                WHEN ISNULL(pay.PayeeType, '') <> 'C'
                    THEN CONCAT('Payee ID ', p.PayeeId, ' is not a customer.')
                WHEN pay.IsClosed = 1
                    THEN CONCAT('Payee ID ', p.PayeeId, ' is closed.')
                WHEN p.IsInvoiceDateValid = 0
                    THEN 'InvoiceDate must be blank, a real Excel date cell, or yyyy-MM-dd text.'
                WHEN LEN(ISNULL(p.CleanInvoiceNumber, '')) > 50
                    THEN 'InvoiceNumber cannot be longer than 50 characters.'
                WHEN d.DupCount > 1
                    THEN CONCAT('InvoiceNumber "', p.CleanInvoiceNumber, '" appears more than once for this customer in this workbook.')
                WHEN ex.SalesId IS NOT NULL
                    THEN CONCAT('InvoiceNumber "', p.CleanInvoiceNumber, '" already exists for this customer.')
                WHEN ISNULL(p.CleanCustomerName, '') <> ISNULL(pay.PayeeName, '')
                    THEN 'CustomerName does not match the resolved customer name; PayeeId will be used.'
                WHEN n.PayeeNet = 0
                    THEN 'This customer''s rows net to zero, so nothing will be posted for them.'
                ELSE NULL
            END                                                 AS [Message]

        FROM Parsed p

        LEFT JOIN dbo.Payee pay
            ON pay.PayeeId = p.PayeeId

        LEFT JOIN dbo.Customer c
            ON c.PayeeId = p.PayeeId

        OUTER APPLY (
            SELECT TOP (1) s.SalesId
            FROM dbo.Sales s
            WHERE p.CleanInvoiceNumber IS NOT NULL
              AND s.ShipId = p.PayeeId
              AND s.SalesDocNumber = p.CleanInvoiceNumber
              AND ISNULL(s.DocType, '') <> 'OB'
        ) ex

        CROSS APPLY (
            SELECT COUNT(*) AS DupCount
            FROM Parsed y
            WHERE p.CleanInvoiceNumber IS NOT NULL
              AND y.CleanInvoiceNumber = p.CleanInvoiceNumber
              AND y.PayeeId = p.PayeeId
        ) d

        CROSS APPLY (
            SELECT SUM(ISNULL(y.Amount, 0)) AS PayeeNet
            FROM Parsed y
            WHERE y.PayeeId = p.PayeeId
              AND y.Amount IS NOT NULL
        ) n

        ORDER BY p.AutoId;
    END

    ------------------------------------------------------------------
    -- AP  /  ARE
    ------------------------------------------------------------------
    ELSE IF @Sec IN ('AP', 'ARE')
    BEGIN
        DECLARE @Party AS TABLE (
            AutoId      INT IDENTITY(1,1),
            PayeeId     INT             NULL,
            PartyName   NVARCHAR(255)   NULL,
            DocNumber   NVARCHAR(100)   NULL,
            Amount      DECIMAL(18,2)   NULL,
            Notes       NVARCHAR(400)   NULL
        );

        -- ARE has no document-number column, so it needs its own shape.
        DECLARE @Emp AS TABLE (
            AutoId      INT IDENTITY(1,1),
            PayeeId     INT             NULL,
            PartyName   NVARCHAR(255)   NULL,
            Amount      DECIMAL(18,2)   NULL,
            Notes       NVARCHAR(400)   NULL
        );

        DECLARE @SheetName NVARCHAR(20) =
            CASE @Sec WHEN 'AP' THEN 'AP' ELSE 'ARE' END;

        BEGIN TRY
            IF @Sec = 'AP'
            BEGIN
                SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [AP$]);';

                INSERT INTO @Party EXEC (@Qry);
            END
            ELSE
            BEGIN
                SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [ARE$]);';

                INSERT INTO @Emp EXEC (@Qry);

                INSERT INTO @Party (PayeeId, PartyName, DocNumber, Amount, Notes)
                SELECT PayeeId, PartyName, NULL, Amount, Notes
                FROM @Emp
                ORDER BY AutoId;
            END
        END TRY
        BEGIN CATCH
            SET @Msg = CONCAT(
                'Could not read a [', @SheetName, '] sheet from this workbook. Check that you picked '
              + 'the right section and that the file is the downloaded ', @SheetName, ' workbook. (',
                ERROR_MESSAGE(), ')');

            THROW 51001, @Msg, 1;
        END CATCH

        SELECT @IgnoredRowCount = COUNT(*)
        FROM @Party
        WHERE Amount IS NULL;

        SELECT
            t.AutoId                                            AS RowNo,
            CAST(t.PayeeId AS NVARCHAR(200))                    AS Key1,
            t.DocNumber                                         AS Key2,
            CAST(NULL AS DATE)                                  AS DocumentDate,
            p.PayeeId                                           AS ResolvedId,
            p.PayeeName                                         AS ResolvedName,
            CAST(NULL AS DECIMAL(18,4))                         AS Qty,
            CAST(NULL AS DECIMAL(18,4))                         AS Price,
            t.Amount                                            AS Amount,
            t.Notes                                             AS Notes,

            CASE
                WHEN t.PayeeId IS NULL          THEN 'Error'
                WHEN p.PayeeId IS NULL          THEN 'Error'
                WHEN t.Amount IS NULL           THEN 'Error'
                WHEN n.PayeeNet = 0             THEN 'Warning'
                ELSE 'OK'
            END                                                 AS Severity,

            CASE
                WHEN t.PayeeId IS NULL
                    THEN 'Payee ID is required.'
                WHEN p.PayeeId IS NULL
                    THEN CONCAT('Payee ID ', t.PayeeId, ' does not exist.')
                WHEN t.Amount IS NULL
                    THEN 'Amount is required.'
                WHEN n.PayeeNet = 0
                    THEN 'This payee''s rows net to zero, so nothing will be posted for them.'
                ELSE NULL
            END                                                 AS [Message]

        FROM @Party t

        LEFT JOIN dbo.Payee p
            ON p.PayeeId = t.PayeeId

        -- The posting procs GROUP BY PayeeId HAVING SUM(Amount) <> 0, so a
        -- payee whose rows cancel out is silently dropped. Say so up front.
        CROSS APPLY (
            SELECT SUM(ISNULL(y.Amount, 0)) AS PayeeNet
            FROM @Party y
            WHERE y.PayeeId = t.PayeeId
              AND y.Amount IS NOT NULL
        ) n

        WHERE t.Amount IS NOT NULL

        ORDER BY t.AutoId;
    END

    ------------------------------------------------------------------
    -- INV
    ------------------------------------------------------------------
    ELSE IF @Sec = 'INV'
    BEGIN
        DECLARE @Inv AS TABLE (
            AutoId      INT IDENTITY(1,1),
            ItemCode    NVARCHAR(100)   NULL,
            ItemName    NVARCHAR(255)   NULL,
            Qty         DECIMAL(18,4)   NULL,
            Price       DECIMAL(18,4)   NULL,
            TotalValue  DECIMAL(18,2)   NULL,
            Notes       NVARCHAR(400)   NULL
        );

        BEGIN TRY
            SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [Inventory$]);';

            INSERT INTO @Inv
            EXEC (@Qry);
        END TRY
        BEGIN CATCH
            SET @Msg = CONCAT(
                'Could not read an [Inventory] sheet from this workbook. Check that you picked the '
              + 'right section and that the file is the downloaded Inventory workbook. (',
                ERROR_MESSAGE(), ')');

            THROW 51001, @Msg, 1;
        END CATCH

        SELECT @IgnoredRowCount = COUNT(*)
        FROM @Inv
        WHERE Qty IS NULL
          AND Price IS NULL
          AND TotalValue IS NULL;

        SELECT
            t.AutoId                                            AS RowNo,
            t.ItemCode                                          AS Key1,
            CAST(NULL AS NVARCHAR(200))                         AS Key2,
            CAST(NULL AS DATE)                                  AS DocumentDate,
            i.ItemId                                            AS ResolvedId,
            i.ItemName                                          AS ResolvedName,
            t.Qty                                               AS Qty,
            t.Price                                             AS Price,
            t.TotalValue                                        AS Amount,
            t.Notes                                             AS Notes,

            CASE
                WHEN NULLIF(LTRIM(RTRIM(t.ItemCode)), '') IS NULL           THEN 'Error'
                WHEN i.MatchCount = 0                                       THEN 'Error'
                WHEN i.MatchCount > 1                                       THEN 'Error'
                WHEN d.DupCount > 1                                         THEN 'Error'
                WHEN t.Qty IS NULL                                          THEN 'Error'
                WHEN t.Price IS NULL                                        THEN 'Error'
                WHEN t.TotalValue IS NULL                                   THEN 'Error'
                WHEN ABS(t.TotalValue - ROUND(t.Qty * t.Price, 2)) > 0.01    THEN 'Error'
                ELSE 'OK'
            END                                                 AS Severity,

            CASE
                WHEN NULLIF(LTRIM(RTRIM(t.ItemCode)), '') IS NULL
                    THEN 'Item code is required.'
                WHEN i.MatchCount = 0
                    THEN CONCAT('Item code "', t.ItemCode, '" does not exist.')
                WHEN i.MatchCount > 1
                    THEN CONCAT('Item code "', t.ItemCode, '" matches ', i.MatchCount, ' products.')
                WHEN d.DupCount > 1
                    THEN CONCAT('Item code "', t.ItemCode, '" appears ', d.DupCount, ' times in this sheet.')
                WHEN t.Qty IS NULL
                    THEN 'Quantity is required.'
                WHEN t.Price IS NULL
                    THEN 'Price is required.'
                WHEN t.TotalValue IS NULL
                    THEN 'Total value is required.'
                WHEN ABS(t.TotalValue - ROUND(t.Qty * t.Price, 2)) > 0.01
                    THEN CONCAT('Total value ', CONVERT(NVARCHAR(30), t.TotalValue),
                                ' does not match quantity x price (',
                                CONVERT(NVARCHAR(30), ROUND(t.Qty * t.Price, 2)), ').')
                ELSE NULL
            END                                                 AS [Message]

        FROM @Inv t

        CROSS APPLY (
            SELECT COUNT(*)       AS MatchCount,
                   MIN(x.ItemId)  AS ItemId,
                   MIN(x.ItemName) AS ItemName
            FROM dbo.Item x
            WHERE x.ItemCode = t.ItemCode
        ) i

        CROSS APPLY (
            SELECT COUNT(*) AS DupCount
            FROM @Inv y
            WHERE y.ItemCode = t.ItemCode
              AND NOT (y.Qty IS NULL AND y.Price IS NULL AND y.TotalValue IS NULL)
        ) d

        WHERE NOT (t.Qty IS NULL AND t.Price IS NULL AND t.TotalValue IS NULL)

        ORDER BY t.AutoId;
    END
END

GO
