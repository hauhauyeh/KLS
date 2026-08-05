
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

CREATE   PROCEDURE [dbo].[OpenBalance_Import]
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
                AutoId        INT IDENTITY(1,1),
                PayeeId       INT             NULL,
                CustomerName  NVARCHAR(255)   NULL,
                InvoiceNumber NVARCHAR(100)   NULL,
                Amount        DECIMAL(18,2)   NULL,
                Notes         NVARCHAR(400)   NULL
            );

            SET @Qry = 'SELECT * FROM OPENROWSET(''Microsoft.ACE.OLEDB.12.0'',
    ''Excel 12.0; HDR=yes; IMEX=1; Database=' + CONVERT(NVARCHAR(255), @FilePath) + ''', [AR$]);';

            INSERT INTO @AR EXEC (@Qry);

            SELECT @PriorRowCount = COUNT(*) FROM dbo.OpenBalanceAR;

            DELETE FROM dbo.OpenBalanceAR;

            -- SalesId stays NULL: an opening balance has no source document
            -- to point at. SalesNum is kept for reference only -- the posting
            -- proc groups by PayeeId and never reads it.
            INSERT INTO dbo.OpenBalanceAR
                (SalesId, SalesNum, PayeeId, AsOfDate, Amount, Notes, CreatedAt)
            SELECT
                NULL,
                TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(t.InvoiceNumber)), '')),
                t.PayeeId,
                @AsOfDate,
                ISNULL(t.Amount, 0),
                t.Notes,
                GETUTCDATE()
            FROM @AR t
            WHERE t.Amount IS NOT NULL
            ORDER BY t.AutoId;

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
