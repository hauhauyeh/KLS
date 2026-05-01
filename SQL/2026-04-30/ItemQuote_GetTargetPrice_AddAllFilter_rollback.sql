-- Rollback: Restore ItemQuote_GetTargetPrice without 'all' filter
DROP PROCEDURE IF EXISTS [dbo].[ItemQuote_GetTargetPrice];
GO
EXEC sp_rename 'ItemQuote_GetTargetPrice_prev', 'ItemQuote_GetTargetPrice';
GO
