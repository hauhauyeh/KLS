-- =============================================================================================
-- BankRecon_RecalcByAccount  (NEW)  — bank-recon-auto-difference-v1
-- Recompute + persist EVERY reconciliation for an account whose StatementDate >= @FromDate, in
-- ASCENDING StatementDate order. Ascending order is required: Fn_BankRecon derives a period's
-- BeginningBalance from the PREVIOUS period's stored EndingBalance, so each period must persist
-- before the next one reads it (cascade).
--
-- @FromDate = the bank-feed PostedDate / ClearedBankDate whose match/unmatch changed the inputs.
--   A match lands BankDate in the period where PrevReconDate <= PostedDate <= StatementDate, i.e. a
--   period with StatementDate >= PostedDate — so recomputing from @FromDate forward covers the changed
--   period and all later ones whose beginning balance shifts.
-- @FromDate = NULL => recompute the whole account (safe fallback, used on unmatch when ClearedBankDate
--   was already null).
--
-- Opens NO transaction of its own — it runs inside the caller's (BankFeed_MatchTx / _UnMatchTx) open
-- transaction, so the recompute is atomic with the match and cannot diverge from it. If no recon rows
-- match (e.g. account has no reconciliations yet) it is a no-op.
-- =============================================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[BankRecon_RecalcByAccount]
    @AccountId INT,
    @FromDate  DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BankReconId INT;

    DECLARE recon_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT BankReconId
        FROM [dbo].[BankRecon]
        WHERE AccountId = @AccountId
          AND (@FromDate IS NULL OR StatementDate >= @FromDate)
        ORDER BY StatementDate ASC;

    OPEN recon_cursor;
    FETCH NEXT FROM recon_cursor INTO @BankReconId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC [dbo].[BankRecon_Recalc] @BankReconId = @BankReconId;
        FETCH NEXT FROM recon_cursor INTO @BankReconId;
    END

    CLOSE recon_cursor;
    DEALLOCATE recon_cursor;
END
GO
