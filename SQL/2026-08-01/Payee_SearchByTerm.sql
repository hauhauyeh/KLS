SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- Payee_SearchByTerm
-- HIDE_SYSTEM_ACCOUNTS 2026-08-01: this SP has no PayeeType filter at all - it
--   returns customers, vendors AND employees to the Incoming Payments payee
--   picker (GET /api/admin/IncomingPayments/SearchPayee). PayeeType appears only
--   in the SELECT list, which is why a keyword scan for "PayeeType" makes it look
--   filtered. Without the new predicate the hidden super admin accounts SYS1/SYS2
--   would be findable here by name or by PayeeId.
--   Only change: AND IsSystemAccount = 0 in the WHERE. No real payee carries the
--   flag, so customers, vendors and every existing employee are unaffected.
-- Baseline: Payee_SearchByTerm_live_baseline.sql
-- Plan:     plan/hidden-super-admin-accounts-v2.md
-- ============================================================
-- EXEC dbo.Payee_SearchByTerm @SearchTerm = N'SYS', @IsActiveOnly = 1
CREATE OR ALTER PROCEDURE [dbo].[Payee_SearchByTerm]
    @SearchTerm NVARCHAR(100),
    @IsActiveOnly   BIT
AS
BEGIN
    SET NOCOUNT ON;

    -- Trim and handle NULL
    DECLARE @term NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@SearchTerm, N'')));
    DECLARE @contains NVARCHAR(200) = N'%' + @term + N'%';
    DECLARE @starts   NVARCHAR(200) = @term + N'%';

    SELECT
        PayeeId,
        PayeeType,
        PayeeName,
        IsClosed
    FROM Payee
    WHERE
        IsSystemAccount = 0
        AND (@IsActiveOnly = 0 OR IsClosed = 0)
        AND (
               PayeeName LIKE @contains
            OR Phone1    LIKE @contains
            OR Phone2    LIKE @contains
            OR Phone3    LIKE @contains
            OR Phone4    LIKE @contains
            OR CONVERT(NVARCHAR(20), PayeeId) LIKE @contains
        )
    ORDER BY
        CASE
            WHEN PayeeName LIKE @starts   THEN 0
            WHEN PayeeName LIKE @contains THEN 1
            ELSE 2
        END,
        PayeeName;
END
GO
