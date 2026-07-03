-- Rollback: drop the filtered unique ratio index.
DROP INDEX IF EXISTS UX_ItemUnit_Ratio ON dbo.ItemUnit
GO
