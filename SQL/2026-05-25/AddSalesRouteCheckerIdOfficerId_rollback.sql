/*
    AddSalesRouteCheckerIdOfficerId_rollback.sql
    2026-05-25

    Reverses AddSalesRouteCheckerIdOfficerId.sql.
    Drops both new FK columns. Checker and Officer text columns are
    untouched (they pre-existed; the forward script never modified them).
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.SalesRoute') AND name = 'CheckerId'
)
BEGIN
    ALTER TABLE dbo.SalesRoute DROP COLUMN CheckerId;
    PRINT '--- CheckerId dropped ---';
END;

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.SalesRoute') AND name = 'OfficerId'
)
BEGIN
    ALTER TABLE dbo.SalesRoute DROP COLUMN OfficerId;
    PRINT '--- OfficerId dropped ---';
END;
