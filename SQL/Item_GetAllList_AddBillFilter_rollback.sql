-- Rollback: restore original Item_GetAllList
DROP PROCEDURE IF EXISTS dbo.Item_GetAllList;

IF OBJECT_ID('dbo.Item_GetAllList_prev') IS NOT NULL
    EXEC sp_rename 'Item_GetAllList_prev', 'Item_GetAllList';
