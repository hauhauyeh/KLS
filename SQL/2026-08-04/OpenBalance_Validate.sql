SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- OpenBalance_Validate
-- 2026-08-04: NEW. Read-only. Everything the Opening Balance screen
-- renders, in one result set: five rows, one per section.
--
-- It is a STATUS QUERY, not a control. Nothing here throws and nothing
-- here blocks -- per decision D3 a section imports and posts even when
-- it does not tie, and the variance is reported until someone fixes it.
--
-- The reconciliation is the point of the whole feature. The four
-- control accounts (@AR, @ARE, @AP, @INV) are ZEROED by
-- GeneralJournal_OBAccount and posted from the subledgers instead, so
-- the Balance a user types on the Account sheet is only ever a CHECK
-- FIGURE. Nothing in the system compared the two before this proc, and
-- on the data as it stands all four disagree.
--
-- HasTrialBalanceRow separates two different user errors that would
-- otherwise share a message (review finding R4):
--   missing @AR row  -> "add an @AR row to the Account sheet"
--   wrong  @AR row   -> "AR is 37,272.12 over the trial balance"
-- Reporting a variance for an absent row sends the user off to audit
-- 1,618 correct AR rows.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[OpenBalance_Validate]  -- EXEC dbo.OpenBalance_Validate

AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------------
    -- Per-section saved rows
    ------------------------------------------------------------------
    DECLARE @Sections TABLE (
        SortOrder       INT,
        Section         NVARCHAR(20),
        GJNumber        INT,
        [RowCount]      INT,
        SectionTotal    DECIMAL(18,2),
        LastImportedAt  DATETIME,
        ControlCode     NVARCHAR(50)    -- NULL for ACCOUNT: it holds the targets, it is not one
    );

    INSERT INTO @Sections (SortOrder, Section, GJNumber, [RowCount], SectionTotal, LastImportedAt, ControlCode)
    SELECT 1, 'ACCOUNT', 0,
           COUNT(*),
           SUM(ISNULL(a.Balance, 0)),
           MAX(a.CreatedAt),
           NULL
    FROM dbo.OpenBalanceAccount a

    UNION ALL
    SELECT 2, 'AR', -1,
           COUNT(*),
           SUM(ISNULL(r.Amount, 0)),
           MAX(r.CreatedAt),
           '@AR'
    FROM dbo.OpenBalanceAR r

    UNION ALL
    SELECT 3, 'AP', -2,
           COUNT(*),
           SUM(ISNULL(p.Amount, 0)),
           MAX(p.CreatedAt),
           '@AP'
    FROM dbo.OpenBalanceAP p

    UNION ALL
    SELECT 4, 'INV', -3,
           COUNT(*),
           SUM(ISNULL(i.TotalValue, 0)),
           MAX(i.CreatedAt),
           '@INV'
    FROM dbo.OpenBalanceInv i

    UNION ALL
    SELECT 5, 'ARE', -4,
           COUNT(*),
           SUM(ISNULL(e.Amount, 0)),
           MAX(e.CreatedAt),
           '@ARE'
    FROM dbo.OpenBalanceARE e;

    ------------------------------------------------------------------
    -- The @OBE plug. Reported on the ACCOUNT row only. It is excluded
    -- from posting by GeneralJournal_OBAccount, so a non-zero value
    -- here is a number the user typed that the system will ignore.
    ------------------------------------------------------------------
    DECLARE @ObeBalance DECIMAL(18,2);

    SELECT @ObeBalance = SUM(ISNULL(Balance, 0))
    FROM dbo.OpenBalanceAccount
    WHERE AccountCode = '@OBE';

    ------------------------------------------------------------------
    -- Result
    ------------------------------------------------------------------
    SELECT
        s.Section,
        s.GJNumber,
        s.[RowCount],
        s.SectionTotal,
        s.LastImportedAt,

        CAST(CASE WHEN gj.GJId IS NULL THEN 0 ELSE 1 END AS BIT)    AS IsPosted,
        gj.CreatedAt                                                AS PostedAt,
        gj.TotalDebitAmount,
        gj.TotalCreditAmount,

        tb.Balance                                                  AS TrialBalance,
        CAST(CASE WHEN tb.AccountCode IS NULL THEN 0 ELSE 1 END AS BIT) AS HasTrialBalanceRow,

        -- NULL for ACCOUNT (nothing to compare it against) and whenever the
        -- Account sheet has no row for this control account -- that case is
        -- reported through HasTrialBalanceRow instead, never as a variance.
        CASE
            WHEN s.ControlCode IS NULL      THEN NULL
            WHEN tb.AccountCode IS NULL     THEN NULL
            ELSE s.SectionTotal - tb.Balance
        END                                                         AS Variance,

        CASE WHEN s.ControlCode IS NULL THEN @ObeBalance ELSE NULL END AS ObeBalance

    FROM @Sections s

    LEFT JOIN dbo.GeneralJournal gj
        ON gj.GJNumber = s.GJNumber

    LEFT JOIN dbo.OpenBalanceAccount tb
        ON tb.AccountCode = s.ControlCode

    ORDER BY s.SortOrder;
END
GO
