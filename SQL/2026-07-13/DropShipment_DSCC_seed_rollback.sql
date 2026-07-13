-- DropShipment_DSCC_seed_rollback.sql
-- 2026-07-13: Conservative rollback for the @DSCC seed. Does NOT delete the account (it may have posted rows).
-- Marks @DSCC Inactive=1 ONLY if it has no journal usage; otherwise leaves it in place and reports for manual review.
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

IF EXISTS (
    SELECT 1
    FROM dbo.TransactionJournalDetail d
    JOIN dbo.Account a ON a.AccountId = d.AccountId
    WHERE a.AccountCode = '@DSCC'
)
BEGIN
    PRINT '@DSCC has journal usage - left in place (NOT deactivated). Manual review required before removal.';
END
ELSE IF EXISTS (SELECT 1 FROM dbo.Account WHERE AccountCode = '@DSCC')
BEGIN
    UPDATE dbo.Account SET Inactive = 1, UpdatedAt = GETDATE() WHERE AccountCode = '@DSCC';
    PRINT '@DSCC had no journal usage - marked Inactive=1.';
END
ELSE
BEGIN
    PRINT '@DSCC not present - nothing to roll back.';
END
