SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ROLLBACK for BankFeedRuleMoneyIn_FallbackPayee.sql
-- Only removes the fallback if no transaction or rule action has used it.

SET XACT_ABORT ON;
BEGIN TRAN;
BEGIN TRY
    DECLARE @FallbackPayeeId INT = 900001;

    IF EXISTS (SELECT 1 FROM dbo.CustomerPayment WHERE PayeeId = @FallbackPayeeId)
        THROW 50852, 'Cannot roll back Bank Feed Income payee because customer payments use it.', 1;

    IF OBJECT_ID('dbo.BankFeedRuleAction', 'U') IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.BankFeedRuleAction WHERE PayeeId = @FallbackPayeeId)
        THROW 50853, 'Cannot roll back Bank Feed Income payee because bank feed rules use it.', 1;

    IF EXISTS (SELECT 1 FROM dbo.TransactionJournalDetail WHERE PayeeId = @FallbackPayeeId)
        THROW 50854, 'Cannot roll back Bank Feed Income payee because journal details use it.', 1;

    DELETE FROM dbo.Payee
    WHERE PayeeId = @FallbackPayeeId
      AND PayeeName = N'Bank Feed Income';

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO
