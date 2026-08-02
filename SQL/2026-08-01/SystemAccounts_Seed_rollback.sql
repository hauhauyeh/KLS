SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
    2026-08-01  Rollback for SystemAccounts_Seed.sql

    Removes the SYS1 / SYS2 accounts in reverse dependency order:
    SystemUser -> Employee -> Payee.

    Deletes by PayeeId AND IsSystemAccount = 1, so it cannot touch a real
    employee even if the ids were reused.

    UserLog rows for their logins are deliberately NOT deleted (plan D5) - the
    login trail is the record that a hidden all-access account was used, and it
    should outlive the account.
*/

DECLARE @Sys1PayeeId INT = 100195;
DECLARE @Sys2PayeeId INT = 100196;

SET XACT_ABORT ON;
BEGIN TRAN;
BEGIN TRY

    DECLARE @Ids TABLE (PayeeId INT PRIMARY KEY);

    INSERT INTO @Ids (PayeeId)
    SELECT PayeeId
    FROM dbo.Payee
    WHERE PayeeId IN (@Sys1PayeeId, @Sys2PayeeId)
      AND IsSystemAccount = 1
      AND PayeeType = 'E';

    IF NOT EXISTS (SELECT 1 FROM @Ids)
        THROW 51020, 'No system accounts found at PayeeId 100195/100196. Nothing to roll back.', 1;

    -- Refuse if either account has been used to create anything. Deleting the
    -- Payee would orphan whatever references it.
    IF EXISTS (SELECT 1 FROM dbo.TransactionJournalDetail d
               INNER JOIN @Ids i ON i.PayeeId = d.PayeeId)
        THROW 51021, 'Rollback refused: a system account has journal activity. Investigate before deleting.', 1;

    DELETE u FROM dbo.SystemUser u INNER JOIN @Ids i ON i.PayeeId = u.PayeeId;
    DELETE e FROM dbo.Employee   e INNER JOIN @Ids i ON i.PayeeId = e.PayeeId;
    DELETE p FROM dbo.Payee      p INNER JOIN @Ids i ON i.PayeeId = p.PayeeId;

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO

-- Verify: expect 0 rows
SELECT PayeeId, PayeeName FROM dbo.Payee WHERE IsSystemAccount = 1;
GO
