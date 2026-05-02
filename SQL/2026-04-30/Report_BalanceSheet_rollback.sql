-- Rollback: Restore Report_BalanceSheet to previous version
-- (reverses Report_BalanceSheet.sql)
DROP PROCEDURE IF EXISTS [dbo].[Report_BalanceSheet];
GO

EXEC sp_rename 'Report_BalanceSheet_prev', 'Report_BalanceSheet';
GO
