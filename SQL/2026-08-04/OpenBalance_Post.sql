SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- OpenBalance_Post
-- 2026-08-04: NEW. Replaces ONE opening balance section's journal.
--
--   EXEC OpenBalance_Unpost @Section   -- clears the old journal
--   EXEC GeneralJournal_OB<Section>    -- posts the saved rows again
--
-- The five GeneralJournal_OB* procs are POST-ONLY: they insert a
-- GeneralJournal header with a fixed GJNumber and assume the number is
-- free. UK_GeneralJournal_GJNumber enforces that, so the unpost is not
-- optional -- it is the contract those procs were written against.
-- (GeneralJournal_OBAccount also deletes GJNumber 1 itself; running it
-- after the unpost is harmless.)
--
-- NO reconciliation call here. Per decision D3 a section imports and
-- posts even when its subledger does not tie to the trial balance --
-- the difference sits in @OBE and is reported by OpenBalance_Validate,
-- which is a read-only status query and never part of the write path.
--
-- Kept separate from OpenBalance_Import so a section can be re-posted
-- from already-saved rows without re-uploading a workbook.
--
-- Sections are independent: each proc owns exactly one GJNumber and
-- none reads another section's staging table, so posting one leaves the
-- other four journals byte-identical (same GJId, same TxId, same totals).
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[OpenBalance_Post]      -- EXEC dbo.OpenBalance_Post @Section = 'AR'

    @Section NVARCHAR(20)

AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Sec NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@Section, ''))));
    DECLARE @Msg NVARCHAR(400);

    IF @Sec NOT IN ('ACCOUNT', 'AR', 'AP', 'INV', 'ARE')
    BEGIN
        SET @Msg = CONCAT(
            'Unknown opening balance section "', ISNULL(@Section, '<null>'),
            '". Expected ACCOUNT, AR, AP, INV or ARE.');

        THROW 51000, @Msg, 1;
    END

    BEGIN TRAN;

        EXEC dbo.OpenBalance_Unpost @Section = @Sec;

        IF @Sec = 'ACCOUNT'
            EXEC dbo.GeneralJournal_OBAccount;
        ELSE IF @Sec = 'AR'
            EXEC dbo.GeneralJournal_OBAR;
        ELSE IF @Sec = 'AP'
            EXEC dbo.GeneralJournal_OBAP;
        ELSE IF @Sec = 'INV'
            EXEC dbo.GeneralJournal_OBINV;
        ELSE IF @Sec = 'ARE'
            EXEC dbo.GeneralJournal_OBARE;

    COMMIT;
END
GO
