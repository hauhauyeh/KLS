SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- OpenBalance_GetRows
-- 2026-08-04: NEW. Read-only. One section's SAVED rows, in the same
-- shape [OpenBalance_ImportPreview] returns, so the download workbook
-- and the preview grid are built from one model.
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

CREATE OR ALTER PROCEDURE [dbo].[OpenBalance_GetRows]   -- EXEC dbo.OpenBalance_GetRows @Section = 'AR'

    @Section NVARCHAR(20)

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
        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY o.OpenAccountId) AS INT)  AS RowNo,
            o.AccountCode                                   AS Key1,
            CAST(NULL AS NVARCHAR(200))                     AS Key2,
            o.AccountId                                     AS ResolvedId,
            a.AccountName                                   AS ResolvedName,
            CAST(NULL AS DECIMAL(18,4))                     AS Qty,
            CAST(NULL AS DECIMAL(18,4))                     AS Price,
            o.Balance                                       AS Amount,
            o.Notes                                         AS Notes,
            CAST('OK' AS NVARCHAR(10))                      AS Severity,
            CAST(NULL AS NVARCHAR(400))                     AS [Message]
        FROM dbo.OpenBalanceAccount o
        LEFT JOIN dbo.Account a ON a.AccountId = o.AccountId
        ORDER BY o.OpenAccountId;

    ELSE IF @Sec = 'AR'
        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY o.OpenARId) AS INT)  AS RowNo,
            CAST(o.PayeeId AS NVARCHAR(200))                AS Key1,
            CAST(o.SalesNum AS NVARCHAR(200))               AS Key2,
            o.PayeeId                                       AS ResolvedId,
            p.PayeeName                                     AS ResolvedName,
            CAST(NULL AS DECIMAL(18,4))                     AS Qty,
            CAST(NULL AS DECIMAL(18,4))                     AS Price,
            o.Amount                                        AS Amount,
            o.Notes                                         AS Notes,
            CAST('OK' AS NVARCHAR(10))                      AS Severity,
            CAST(NULL AS NVARCHAR(400))                     AS [Message]
        FROM dbo.OpenBalanceAR o
        LEFT JOIN dbo.Payee p ON p.PayeeId = o.PayeeId
        ORDER BY o.OpenARId;

    ELSE IF @Sec = 'AP'
        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY o.OpenAPId) AS INT)  AS RowNo,
            CAST(o.PayeeId AS NVARCHAR(200))                AS Key1,
            CAST(o.PurchaseNum AS NVARCHAR(200))            AS Key2,
            o.PayeeId                                       AS ResolvedId,
            p.PayeeName                                     AS ResolvedName,
            CAST(NULL AS DECIMAL(18,4))                     AS Qty,
            CAST(NULL AS DECIMAL(18,4))                     AS Price,
            o.Amount                                        AS Amount,
            o.Notes                                         AS Notes,
            CAST('OK' AS NVARCHAR(10))                      AS Severity,
            CAST(NULL AS NVARCHAR(400))                     AS [Message]
        FROM dbo.OpenBalanceAP o
        LEFT JOIN dbo.Payee p ON p.PayeeId = o.PayeeId
        ORDER BY o.OpenAPId;

    ELSE IF @Sec = 'ARE'
        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY o.OpenAREId) AS INT)  AS RowNo,
            CAST(o.PayeeId AS NVARCHAR(200))                AS Key1,
            CAST(NULL AS NVARCHAR(200))                     AS Key2,
            o.PayeeId                                       AS ResolvedId,
            p.PayeeName                                     AS ResolvedName,
            CAST(NULL AS DECIMAL(18,4))                     AS Qty,
            CAST(NULL AS DECIMAL(18,4))                     AS Price,
            o.Amount                                        AS Amount,
            o.Notes                                         AS Notes,
            CAST('OK' AS NVARCHAR(10))                      AS Severity,
            CAST(NULL AS NVARCHAR(400))                     AS [Message]
        FROM dbo.OpenBalanceARE o
        LEFT JOIN dbo.Payee p ON p.PayeeId = o.PayeeId
        ORDER BY o.OpenAREId;

    ELSE IF @Sec = 'INV'
        SELECT
            CAST(ROW_NUMBER() OVER (ORDER BY o.OpenInvId) AS INT)  AS RowNo,
            o.ItemCode                                      AS Key1,
            CAST(NULL AS NVARCHAR(200))                     AS Key2,
            o.ItemId                                        AS ResolvedId,
            i.ItemName                                      AS ResolvedName,
            o.Qty                                           AS Qty,
            o.Price                                         AS Price,
            o.TotalValue                                    AS Amount,
            o.Notes                                         AS Notes,
            CAST('OK' AS NVARCHAR(10))                      AS Severity,
            CAST(NULL AS NVARCHAR(400))                     AS [Message]
        FROM dbo.OpenBalanceInv o
        LEFT JOIN dbo.Item i ON i.ItemId = o.ItemId
        ORDER BY o.OpenInvId;
END
GO
