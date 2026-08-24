SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- Bank Feed rule money-in fallback payee
-- Plan: plan-03b-bank-feed-rule-money-in-apply.md (Slice 2)
-- Rollback: BankFeedRuleMoneyIn_FallbackPayee_rollback.sql
-- =============================================================================================

SET XACT_ABORT ON;
BEGIN TRAN;
BEGIN TRY
    DECLARE @FallbackPayeeId INT = 900001;

    IF EXISTS (SELECT 1 FROM dbo.Payee
               WHERE PayeeId = @FallbackPayeeId
                 AND PayeeName <> N'Bank Feed Income')
        THROW 50850, 'PayeeId 900001 is already used by another payee.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Payee
               WHERE PayeeName = N'Bank Feed Income'
                 AND PayeeId <> @FallbackPayeeId)
        THROW 50851, 'Bank Feed Income payee already exists with a different PayeeId.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Payee WHERE PayeeId = @FallbackPayeeId)
    BEGIN
        INSERT INTO dbo.Payee
            (PayeeId, PayeeType, PayeeName, IsClosed, IsSystemAccount)
        VALUES
            (@FallbackPayeeId, N'O', N'Bank Feed Income', 0, 1);
    END
    ELSE
    BEGIN
        UPDATE dbo.Payee
        SET PayeeType = N'O',
            PayeeName = N'Bank Feed Income',
            IsClosed = 0,
            IsSystemAccount = 1,
            UpdatedAt = GETUTCDATE()
        WHERE PayeeId = @FallbackPayeeId;
    END

    COMMIT TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    THROW;
END CATCH
GO
