/*
    AddSalesRouteLoaderId_rollback.sql
    2026-05-25

    Reverses AddSalesRouteLoaderId.sql.
    Drops the LoaderId column. The Loader text column is untouched (it
    pre-existed and was never modified by the forward script).
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.SalesRoute') AND name = 'LoaderId'
)
BEGIN
    ALTER TABLE dbo.SalesRoute DROP COLUMN LoaderId;
    PRINT '--- LoaderId column dropped ---';
END
ELSE
BEGIN
    PRINT '--- LoaderId column does not exist, nothing to drop ---';
END;
