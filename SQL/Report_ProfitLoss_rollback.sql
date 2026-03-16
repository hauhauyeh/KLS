-- Rollback: Restore Report_ProfitLoss to previous version
-- (reverses Report_ProfitLoss.sql)
DROP PROCEDURE IF EXISTS [dbo].[Report_ProfitLoss];
GO

EXEC sp_rename 'Report_ProfitLoss_prev', 'Report_ProfitLoss';
GO
