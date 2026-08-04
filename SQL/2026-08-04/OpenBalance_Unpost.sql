SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- OpenBalance_Unpost
-- 2026-08-04: NEW. Removes ONE opening balance section's journal.
--
-- The single DELETE below is the COMPLETE unpost. Do not add a
-- hand-written DELETE against TransactionJournal here:
--
--   DELETE GeneralJournal
--     -> FK_GeneralJournalDetail_GeneralJournal  CASCADE   (GJ detail)
--     -> TRG_Delete_GJTx  AFTER DELETE
--          DELETE TransactionJournal WHERE SourceDocType='General Journal'
--                                      AND SourceDocNumber = <GJNumber>
--            -> TRG_Delete_Tx  INSTEAD OF DELETE
--                 INSERT RecalculationLog (queues @INV recalc)
--                 DELETE TransactionJournal
--                   -> FK_TransactionJournalDetail_...  CASCADE  (Tx detail)
--
-- Going through GeneralJournal is what makes the RecalculationLog
-- queueing happen. Deleting TransactionJournal directly skips it and
-- leaves inventory averages stale.
--
-- Measured on KLS-2026 for all five sections at once (rolled back):
--   GJ -5, GJDetail -4554, TJ -5, TJDetail -4554, RecalculationLog +1858,
--   zero orphans left behind.
--
-- @Section is resolved through a fixed map, never cast. An unknown or
-- blank value RAISES -- it must never fall through to a no-op DELETE.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[OpenBalance_Unpost]    -- EXEC dbo.OpenBalance_Unpost @Section = 'AR'

    @Section NVARCHAR(20)

AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Sec NVARCHAR(20) = UPPER(LTRIM(RTRIM(ISNULL(@Section, ''))));
    DECLARE @GJNumber INT;
    DECLARE @Msg NVARCHAR(400);

    SELECT @GJNumber = m.GJNumber
    FROM (VALUES
            ('ACCOUNT',  1),
            ('AR',      -1),
            ('AP',      -2),
            ('INV',     -3),
            ('ARE',     -4)
         ) AS m (Section, GJNumber)
    WHERE m.Section = @Sec;

    IF @GJNumber IS NULL
    BEGIN
        SET @Msg = CONCAT(
            'Unknown opening balance section "', ISNULL(@Section, '<null>'),
            '". Expected ACCOUNT, AR, AP, INV or ARE.');

        THROW 51000, @Msg, 1;
    END

    BEGIN TRAN;

        DELETE FROM dbo.GeneralJournal
        WHERE GJNumber = @GJNumber;

    COMMIT;
END
GO
