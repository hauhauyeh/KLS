-- Rollback for Fn_ItemUnit_IsUsed (new function). Do not run once DeleteUnit depends on it.
DROP FUNCTION IF EXISTS [dbo].[Fn_ItemUnit_IsUsed]
GO
