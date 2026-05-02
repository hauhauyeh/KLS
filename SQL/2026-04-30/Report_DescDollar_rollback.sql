-- Rollback: drop new SP and restore previous version
DROP PROCEDURE IF EXISTS [dbo].[Report_DescDollar];
GO
EXEC sp_rename 'Report_DescDollar_prev', 'Report_DescDollar';
GO
