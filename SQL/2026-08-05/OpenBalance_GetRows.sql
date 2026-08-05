SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- OpenBalance_GetRows
-- 2026-08-04: NEW. Read-only. One section's SAVED rows, in the same
-- shape [OpenBalance_ImportPreview] returns, so the download workbook
-- and the preview grid are built from one model.
-- 2026-08-04: Prefill download with the active master list when
-- @IncludeMasterList = 1. Export keeps @IncludeMasterList = 0.
--
-- This is what makes the round trip work: the download is populated
-- with current data, the user edits three rows, and re-uploads. The
-- informational name columns are refreshed from the database here and
-- ignored on the way back in, so the file stays reviewable without
-- becoming a second source of truth.
--
-- Every column is CAST to the type OpenBalanceExcelRow declares. ROW_NUMBER()
-- returns BIGINT, which EF cannot map onto an int property -- it fails at
-- materialisation with "Unable to cast object of type 'System.Int64' to type
-- 'System.Int32'", naming no column. Do not drop these casts.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[OpenBalance_GetRows]   -- EXEC dbo.OpenBalance_GetRows @Section = 'AR', @IncludeMasterList = 1

    @Section           NVARCHAR(20),
    @IncludeMasterList BIT = 0

AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Sec NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@Section, ''))));
    DECLARE @Msg NVARCHAR(400);

    IF @Sec NOT IN ('ACCOUNT', 'AR', 'AP', 'INV', 'ARE')
    BEGIN
        SET @Msg = CONCAT(
            'Unknown opening balance section "', ISNULL(@Section, '<null>'),
            '". Expected ACCOUNT, AR, AP, INV or ARE.');

        THROW 51000, @Msg, 1;
    END

    IF @Sec = 'ACCOUNT'
    BEGIN
        ;WITH Merged AS (
            SELECT
                o.OpenAccountId                                  AS SortId,
                o.AccountCode                                    AS Key1,
                CAST(NULL AS NVARCHAR(200))                      AS Key2,
                o.AccountId                                      AS ResolvedId,
                a.AccountName                                    AS ResolvedName,
                CAST(NULL AS DECIMAL(18,4))                      AS Qty,
                CAST(NULL AS DECIMAL(18,4))                      AS Price,
                o.Balance                                        AS Amount,
                o.Notes                                          AS Notes,
                c.ClassCode                                      AS ClassCode,
                a.SortOrder                                      AS AccountSortOrder
            FROM dbo.OpenBalanceAccount o
            LEFT JOIN dbo.Account a ON a.AccountId = o.AccountId
            LEFT JOIN dbo.AccountCategory c ON c.AccountCategoryId = a.AccountCategoryId

            UNION ALL

            SELECT
                NULL                                             AS SortId,
                a.AccountCode                                    AS Key1,
                CAST(NULL AS NVARCHAR(200))                      AS Key2,
                a.AccountId                                      AS ResolvedId,
                a.AccountName                                    AS ResolvedName,
                CAST(NULL AS DECIMAL(18,4))                      AS Qty,
                CAST(NULL AS DECIMAL(18,4))                      AS Price,
                CAST(NULL AS DECIMAL(18,2))                      AS Amount,
                CAST(NULL AS NVARCHAR(400))                      AS Notes,
                c.ClassCode                                      AS ClassCode,
                a.SortOrder                                      AS AccountSortOrder
            FROM dbo.Account a
            INNER JOIN dbo.AccountCategory c ON c.AccountCategoryId = a.AccountCategoryId
            WHERE @IncludeMasterList = 1
              AND c.ClassCode IN ('A','L','Q')
              AND a.Inactive = 0
              AND a.AccountCode <> '@OBE'
              AND NOT EXISTS (
                    SELECT 1
                    FROM dbo.OpenBalanceAccount o
                    WHERE o.AccountCode = a.AccountCode
              )
        )
        SELECT
            CAST(ROW_NUMBER() OVER (
                ORDER BY
                    CASE ClassCode WHEN 'A' THEN 1 WHEN 'L' THEN 2 WHEN 'Q' THEN 3 ELSE 9 END,
                    AccountSortOrder,
                    Key1,
                    SortId
            ) AS INT)                                           AS RowNo,
            CAST(Key1 AS NVARCHAR(200))                         AS Key1,
            Key2                                                AS Key2,
            ResolvedId                                          AS ResolvedId,
            ResolvedName                                        AS ResolvedName,
            Qty                                                 AS Qty,
            Price                                               AS Price,
            Amount                                              AS Amount,
            Notes                                               AS Notes,
            CAST('OK' AS NVARCHAR(10))                          AS Severity,
            CAST(NULL AS NVARCHAR(400))                         AS [Message]
        FROM Merged
        ORDER BY
            CASE ClassCode WHEN 'A' THEN 1 WHEN 'L' THEN 2 WHEN 'Q' THEN 3 ELSE 9 END,
            AccountSortOrder,
            Key1,
            SortId;
    END

    ELSE IF @Sec = 'AR'
    BEGIN
        ;WITH Merged AS (
            SELECT
                o.OpenARId                                      AS SortId,
                CAST(o.PayeeId AS NVARCHAR(200))                AS Key1,
                -- 2026-08-05: SalesNum is NVARCHAR(50) holding the client's own
                -- invoice number, so the CAST it used to need is gone. Old code:
                -- CAST(o.SalesNum AS NVARCHAR(200))            AS Key2,
                o.SalesNum                                      AS Key2,
                o.PayeeId                                       AS ResolvedId,
                p.PayeeName                                     AS ResolvedName,
                CAST(NULL AS DECIMAL(18,4))                     AS Qty,
                CAST(NULL AS DECIMAL(18,4))                     AS Price,
                o.Amount                                        AS Amount,
                o.Notes                                         AS Notes,
                o.PayeeId                                       AS SortPayeeId
            FROM dbo.OpenBalanceAR o
            LEFT JOIN dbo.Payee p ON p.PayeeId = o.PayeeId

            UNION ALL

            SELECT
                NULL                                            AS SortId,
                CAST(c.PayeeId AS NVARCHAR(200))                AS Key1,
                CAST(NULL AS NVARCHAR(200))                     AS Key2,
                c.PayeeId                                       AS ResolvedId,
                p.PayeeName                                     AS ResolvedName,
                CAST(NULL AS DECIMAL(18,4))                     AS Qty,
                CAST(NULL AS DECIMAL(18,4))                     AS Price,
                CAST(NULL AS DECIMAL(18,2))                     AS Amount,
                CAST(NULL AS NVARCHAR(400))                     AS Notes,
                c.PayeeId                                       AS SortPayeeId
            FROM dbo.Customer c
            INNER JOIN dbo.Payee p ON p.PayeeId = c.PayeeId
            WHERE @IncludeMasterList = 1
              AND p.IsClosed = 0
              AND NOT EXISTS (
                    SELECT 1
                    FROM dbo.OpenBalanceAR o
                    WHERE o.PayeeId = c.PayeeId
              )
        )
        SELECT
            CAST(ROW_NUMBER() OVER (
                ORDER BY
                    CASE WHEN ResolvedName IS NULL THEN 1 ELSE 0 END,
                    ResolvedName,
                    SortPayeeId,
                    SortId
            ) AS INT)                                           AS RowNo,
            Key1                                                AS Key1,
            Key2                                                AS Key2,
            ResolvedId                                          AS ResolvedId,
            ResolvedName                                        AS ResolvedName,
            Qty                                                 AS Qty,
            Price                                               AS Price,
            Amount                                              AS Amount,
            Notes                                               AS Notes,
            CAST('OK' AS NVARCHAR(10))                          AS Severity,
            CAST(NULL AS NVARCHAR(400))                         AS [Message]
        FROM Merged
        ORDER BY
            CASE WHEN ResolvedName IS NULL THEN 1 ELSE 0 END,
            ResolvedName,
            SortPayeeId,
            SortId;
    END

    ELSE IF @Sec = 'AP'
    BEGIN
        ;WITH Merged AS (
            SELECT
                o.OpenAPId                                      AS SortId,
                CAST(o.PayeeId AS NVARCHAR(200))                AS Key1,
                -- 2026-08-05: PurchaseNum is NVARCHAR(200) holding the client's own
                -- bill number, so the CAST it used to need is gone. Old code:
                -- CAST(o.PurchaseNum AS NVARCHAR(200))         AS Key2,
                o.PurchaseNum                                   AS Key2,
                o.PayeeId                                       AS ResolvedId,
                p.PayeeName                                     AS ResolvedName,
                CAST(NULL AS DECIMAL(18,4))                     AS Qty,
                CAST(NULL AS DECIMAL(18,4))                     AS Price,
                o.Amount                                        AS Amount,
                o.Notes                                         AS Notes,
                o.PayeeId                                       AS SortPayeeId
            FROM dbo.OpenBalanceAP o
            LEFT JOIN dbo.Payee p ON p.PayeeId = o.PayeeId

            -- 2026-08-05: adopted legacy bills are excluded from the workbook.
            -- They are already paid and cannot be replaced by an import, so
            -- offering them for editing would only let the client upload a
            -- second, unpaid copy of a bill that is already recorded. They stay
            -- in OpenBalanceAP and keep posting through GeneralJournal_OBAP, so
            -- the opening AP balance in the ledger is unaffected.
            -- Rows this import created live in 50001-59999 and remain editable.
            WHERE NOT EXISTS (
                    SELECT 1
                    FROM dbo.Purchase ap
                    WHERE ap.PurchaseId = o.PurchaseId
                      AND ap.PurchaseNumber NOT BETWEEN 50001 AND 59999
              )

            UNION ALL

            SELECT
                NULL                                            AS SortId,
                CAST(v.PayeeId AS NVARCHAR(200))                AS Key1,
                CAST(NULL AS NVARCHAR(200))                     AS Key2,
                v.PayeeId                                       AS ResolvedId,
                p.PayeeName                                     AS ResolvedName,
                CAST(NULL AS DECIMAL(18,4))                     AS Qty,
                CAST(NULL AS DECIMAL(18,4))                     AS Price,
                CAST(NULL AS DECIMAL(18,2))                     AS Amount,
                CAST(NULL AS NVARCHAR(400))                     AS Notes,
                v.PayeeId                                       AS SortPayeeId
            FROM dbo.Vendor v
            INNER JOIN dbo.Payee p ON p.PayeeId = v.PayeeId
            WHERE @IncludeMasterList = 1
              AND p.IsClosed = 0
              -- Only editable rows suppress a vendor's blank starter row. A
              -- vendor whose only opening rows are adopted and paid still needs
              -- a blank row, or they would vanish from the workbook entirely.
              AND NOT EXISTS (
                    SELECT 1
                    FROM dbo.OpenBalanceAP o
                    LEFT JOIN dbo.Purchase ap ON ap.PurchaseId = o.PurchaseId
                    WHERE o.PayeeId = v.PayeeId
                      AND (ap.PurchaseId IS NULL
                           OR ap.PurchaseNumber BETWEEN 50001 AND 59999)
              )
        )
        SELECT
            CAST(ROW_NUMBER() OVER (
                ORDER BY
                    CASE WHEN ResolvedName IS NULL THEN 1 ELSE 0 END,
                    ResolvedName,
                    SortPayeeId,
                    SortId
            ) AS INT)                                           AS RowNo,
            Key1                                                AS Key1,
            Key2                                                AS Key2,
            ResolvedId                                          AS ResolvedId,
            ResolvedName                                        AS ResolvedName,
            Qty                                                 AS Qty,
            Price                                               AS Price,
            Amount                                              AS Amount,
            Notes                                               AS Notes,
            CAST('OK' AS NVARCHAR(10))                          AS Severity,
            CAST(NULL AS NVARCHAR(400))                         AS [Message]
        FROM Merged
        ORDER BY
            CASE WHEN ResolvedName IS NULL THEN 1 ELSE 0 END,
            ResolvedName,
            SortPayeeId,
            SortId;
    END

    ELSE IF @Sec = 'ARE'
    BEGIN
        ;WITH Merged AS (
            SELECT
                o.OpenAREId                                     AS SortId,
                CAST(o.PayeeId AS NVARCHAR(200))                AS Key1,
                CAST(NULL AS NVARCHAR(200))                     AS Key2,
                o.PayeeId                                       AS ResolvedId,
                p.PayeeName                                     AS ResolvedName,
                CAST(NULL AS DECIMAL(18,4))                     AS Qty,
                CAST(NULL AS DECIMAL(18,4))                     AS Price,
                o.Amount                                        AS Amount,
                o.Notes                                         AS Notes,
                o.PayeeId                                       AS SortPayeeId
            FROM dbo.OpenBalanceARE o
            LEFT JOIN dbo.Payee p ON p.PayeeId = o.PayeeId

            UNION ALL

            SELECT
                NULL                                            AS SortId,
                CAST(e.PayeeId AS NVARCHAR(200))                AS Key1,
                CAST(NULL AS NVARCHAR(200))                     AS Key2,
                e.PayeeId                                       AS ResolvedId,
                p.PayeeName                                     AS ResolvedName,
                CAST(NULL AS DECIMAL(18,4))                     AS Qty,
                CAST(NULL AS DECIMAL(18,4))                     AS Price,
                CAST(NULL AS DECIMAL(18,2))                     AS Amount,
                CAST(NULL AS NVARCHAR(400))                     AS Notes,
                e.PayeeId                                       AS SortPayeeId
            FROM dbo.Employee e
            INNER JOIN dbo.Payee p ON p.PayeeId = e.PayeeId
            WHERE @IncludeMasterList = 1
              AND p.IsClosed = 0
              AND NOT EXISTS (
                    SELECT 1
                    FROM dbo.OpenBalanceARE o
                    WHERE o.PayeeId = e.PayeeId
              )
        )
        SELECT
            CAST(ROW_NUMBER() OVER (
                ORDER BY
                    CASE WHEN ResolvedName IS NULL THEN 1 ELSE 0 END,
                    ResolvedName,
                    SortPayeeId,
                    SortId
            ) AS INT)                                           AS RowNo,
            Key1                                                AS Key1,
            Key2                                                AS Key2,
            ResolvedId                                          AS ResolvedId,
            ResolvedName                                        AS ResolvedName,
            Qty                                                 AS Qty,
            Price                                               AS Price,
            Amount                                              AS Amount,
            Notes                                               AS Notes,
            CAST('OK' AS NVARCHAR(10))                          AS Severity,
            CAST(NULL AS NVARCHAR(400))                         AS [Message]
        FROM Merged
        ORDER BY
            CASE WHEN ResolvedName IS NULL THEN 1 ELSE 0 END,
            ResolvedName,
            SortPayeeId,
            SortId;
    END

    ELSE IF @Sec = 'INV'
    BEGIN
        ;WITH Merged AS (
            SELECT
                o.OpenInvId                                     AS SortId,
                o.ItemCode                                      AS Key1,
                CAST(NULL AS NVARCHAR(200))                     AS Key2,
                o.ItemId                                        AS ResolvedId,
                i.ItemName                                      AS ResolvedName,
                o.Qty                                           AS Qty,
                o.Price                                         AS Price,
                o.TotalValue                                    AS Amount,
                o.Notes                                         AS Notes
            FROM dbo.OpenBalanceInv o
            LEFT JOIN dbo.Item i ON i.ItemId = o.ItemId

            UNION ALL

            SELECT
                NULL                                            AS SortId,
                i.ItemCode                                      AS Key1,
                CAST(NULL AS NVARCHAR(200))                     AS Key2,
                i.ItemId                                        AS ResolvedId,
                i.ItemName                                      AS ResolvedName,
                CAST(NULL AS DECIMAL(18,4))                     AS Qty,
                CAST(NULL AS DECIMAL(18,4))                     AS Price,
                CAST(NULL AS DECIMAL(18,2))                     AS Amount,
                CAST(NULL AS NVARCHAR(400))                     AS Notes
            FROM dbo.Item i
            WHERE @IncludeMasterList = 1
              AND i.Inactive = 0
              AND i.IsDeleted = 0
              AND i.ItemType = 'Inventory'
              AND NOT EXISTS (
                    SELECT 1
                    FROM dbo.OpenBalanceInv o
                    WHERE o.ItemCode = i.ItemCode
              )
        )
        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY Key1, SortId) AS INT) AS RowNo,
            CAST(Key1 AS NVARCHAR(200))                         AS Key1,
            Key2                                                AS Key2,
            ResolvedId                                          AS ResolvedId,
            ResolvedName                                        AS ResolvedName,
            Qty                                                 AS Qty,
            Price                                               AS Price,
            Amount                                              AS Amount,
            Notes                                               AS Notes,
            CAST('OK' AS NVARCHAR(10))                          AS Severity,
            CAST(NULL AS NVARCHAR(400))                         AS [Message]
        FROM Merged
        ORDER BY Key1, SortId;
    END
END
GO
