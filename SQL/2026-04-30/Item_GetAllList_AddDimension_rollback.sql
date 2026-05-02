-- Rollback: Drop new SP and restore _prev
DROP PROCEDURE IF EXISTS [dbo].[Item_GetAllList];
GO
EXEC sp_rename 'Item_GetAllList_prev', 'Item_GetAllList';
GO
