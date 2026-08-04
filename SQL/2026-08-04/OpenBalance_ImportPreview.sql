SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- OpenBalance_ImportPreview
-- 2026-08-04: NEW. Read-only companion to OpenBalance_Import.
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
    @DownloadedAt   DATETIME OUTPUT

AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Sec  NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@Section, ''))));
    DECLARE @Qry  NVARCHAR(MAX);
    DECLARE @Msg  NVARCHAR(400);

    SET @DownloadedAt = NULL;

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

        SELECT
            t.AutoId                                            AS RowNo,
            t.AccountCode                                       AS Key1,
            CAST(NULL AS NVARCHAR(200))                         AS Key2,
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
        ) d

        ORDER BY t.AutoId;
    END

    ------------------------------------------------------------------
    -- AR  /  AP  /  ARE   -- same shape, different sheet and label
    ------------------------------------------------------------------
    ELSE IF @Sec IN ('AR', 'AP', 'ARE')
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
            CASE @Sec WHEN 'AR' THEN 'AR' WHEN 'AP' THEN 'AP' ELSE 'ARE' END;

        BEGIN TRY
            IF @Sec = 'AR'
            BEGIN
                SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [AR$]);';

                INSERT INTO @Party EXEC (@Qry);
            END
            ELSE IF @Sec = 'AP'
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

        SELECT
            t.AutoId                                            AS RowNo,
            CAST(t.PayeeId AS NVARCHAR(200))                    AS Key1,
            t.DocNumber                                         AS Key2,
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
        ) n

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

        SELECT
            t.AutoId                                            AS RowNo,
            t.ItemCode                                          AS Key1,
            CAST(NULL AS NVARCHAR(200))                         AS Key2,
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
        ) d

        ORDER BY t.AutoId;
    END
END
GO
