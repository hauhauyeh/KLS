USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- Item.PackSize backfill
-- 2026-07-10: some Item rows have a NULL PackSize. PackSize is derived
--   from Item.SetPacking by [Fn_Calc_FromPack1] -- it is the text after
--   the first '/' or ':', and an empty string when there is no separator.
--   This script recomputes it, using the same expression the proc uses.
--
-- SCOPE: rows WHERE PackSize IS NULL. Nothing else is touched.
--
--   Two rows qualify on the 2026-07-10 snapshot of KLS-2026:
--     ItemId 266   SetPacking 'cs'        -> ''       (no separator)
--     ItemId 7073  SetPacking 'cs:240ea'  -> '240ea'
--
--   An empty string, not NULL, is the correct value for a separator-less
--   SetPacking: that is what Fn_Calc_FromPack1 returns (ELSE ''), and 579
--   existing rows already store '' rather than NULL.
--
-- DELIBERATELY NOT FIXED: 9 rows where PackSize is non-NULL but disagrees
--   with what SetPacking would derive -- e.g. ItemId 1760 stores
--   '10pk2.2lb' while SetPacking says 'cs/12pk2.2lb', and ItemId 4917
--   stores '1000ct' against a bare 'cs'. Those look hand-edited, and it is
--   not knowable from here which side is right. They are listed by the
--   audit query in step 4 -- review them separately. Widening this script's
--   WHERE clause to PackSize <> Derived would silently overwrite them.
--
-- The expression is inlined rather than calling Fn_Calc_FromPack1 because
--   that proc returns PackSize through an OUTPUT parameter and can only be
--   run one row at a time. It sets @PackSize once and never reassigns it,
--   so the two are equivalent. Verified against the 3,475 rows that already
--   have a value: 3,466 reproduce exactly, and the 9 that do not are the
--   hand-edited rows above.
--
-- Idempotent: re-running matches nothing, because PackSize is no longer NULL.
-- ============================================================

SET XACT_ABORT ON;
GO

-- ------------------------------------------------------------
-- 1. Preview. Run this alone first and eyeball the rows.
-- ------------------------------------------------------------
SELECT  i.ItemId,
        i.ItemName,
        CurrentPackSize = '<NULL>',
        SetPacking      = ISNULL(i.SetPacking, '<NULL>'),
        NewPackSize     = '[' + CASE
                              WHEN CHARINDEX('/', i.SetPacking) > 0
                                  THEN SUBSTRING(i.SetPacking, CHARINDEX('/', i.SetPacking) + 1, LEN(i.SetPacking))
                              WHEN CHARINDEX(':', i.SetPacking) > 0
                                  THEN SUBSTRING(i.SetPacking, CHARINDEX(':', i.SetPacking) + 1, LEN(i.SetPacking))
                              ELSE ''
                          END + ']'
FROM    dbo.Item i
WHERE   i.PackSize IS NULL
ORDER BY i.ItemId;
GO

-- ------------------------------------------------------------
-- 2. Backfill. Captures the before/after of every row it changes,
--    so step 3 can undo it exactly.
-- ------------------------------------------------------------
BEGIN TRY
    BEGIN TRAN;

    DECLARE @Changed TABLE (
        ItemId      INT           NOT NULL,
        SetPacking  NVARCHAR(200) NULL,
        OldPackSize NVARCHAR(200) NULL,
        NewPackSize NVARCHAR(200) NULL
    );

    UPDATE  i
    SET     i.PackSize = CASE
                            WHEN CHARINDEX('/', i.SetPacking) > 0
                                THEN SUBSTRING(i.SetPacking, CHARINDEX('/', i.SetPacking) + 1, LEN(i.SetPacking))
                            WHEN CHARINDEX(':', i.SetPacking) > 0
                                THEN SUBSTRING(i.SetPacking, CHARINDEX(':', i.SetPacking) + 1, LEN(i.SetPacking))
                            ELSE ''
                        END
    OUTPUT  inserted.ItemId, inserted.SetPacking, deleted.PackSize, inserted.PackSize
    INTO    @Changed (ItemId, SetPacking, OldPackSize, NewPackSize)
    FROM    dbo.Item i
    WHERE   i.PackSize IS NULL;          -- the only rows in scope

    SELECT RowsUpdated = COUNT(*) FROM @Changed;
    SELECT * FROM @Changed ORDER BY ItemId;

    -- Nothing should be NULL any more, and nothing outside the scope moved.
    IF EXISTS (SELECT 1 FROM dbo.Item WHERE PackSize IS NULL)
        THROW 51000, 'PackSize is still NULL on at least one row. Rolled back.', 1;

    -- Print the rollback statement for step 3 before committing.
    PRINT '--- To undo, run step 3 with these ItemIds:';
    SELECT RollbackItemIds = STRING_AGG(CAST(ItemId AS NVARCHAR(20)), ',') FROM @Changed;

    COMMIT TRAN;
    PRINT '--- Committed.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;
    THROW;
END CATCH;
GO

-- ------------------------------------------------------------
-- 3. Rollback, if needed. Restores NULL on the rows step 2 changed.
--    Paste the ItemIds that step 2 printed. Scoped by IN (...) so it
--    cannot null out rows that were already populated.
-- ------------------------------------------------------------
-- UPDATE dbo.Item SET PackSize = NULL WHERE ItemId IN (266, 7073);
-- GO

-- ------------------------------------------------------------
-- 4. Audit, not a fix. Rows whose stored PackSize disagrees with what
--    SetPacking derives. Review by hand; this script never writes them.
-- ------------------------------------------------------------
SELECT  i.ItemId,
        i.ItemName,
        i.SetPacking,
        StoredPackSize  = '[' + i.PackSize + ']',
        DerivedPackSize = '[' + CASE
                              WHEN CHARINDEX('/', i.SetPacking) > 0
                                  THEN SUBSTRING(i.SetPacking, CHARINDEX('/', i.SetPacking) + 1, LEN(i.SetPacking))
                              WHEN CHARINDEX(':', i.SetPacking) > 0
                                  THEN SUBSTRING(i.SetPacking, CHARINDEX(':', i.SetPacking) + 1, LEN(i.SetPacking))
                              ELSE ''
                          END + ']'
FROM    dbo.Item i
WHERE   i.PackSize IS NOT NULL
  AND   i.PackSize <> CASE
                          WHEN CHARINDEX('/', i.SetPacking) > 0
                              THEN SUBSTRING(i.SetPacking, CHARINDEX('/', i.SetPacking) + 1, LEN(i.SetPacking))
                          WHEN CHARINDEX(':', i.SetPacking) > 0
                              THEN SUBSTRING(i.SetPacking, CHARINDEX(':', i.SetPacking) + 1, LEN(i.SetPacking))
                          ELSE ''
                      END
ORDER BY i.ItemId;
GO
