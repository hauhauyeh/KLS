-- Rollback: Restore Item_ListActiveForKeybox to sort by ItemName
DROP PROCEDURE IF EXISTS [dbo].[Item_ListActiveForKeybox];
GO
EXEC sp_rename 'Item_ListActiveForKeybox_prev', 'Item_ListActiveForKeybox';
GO
