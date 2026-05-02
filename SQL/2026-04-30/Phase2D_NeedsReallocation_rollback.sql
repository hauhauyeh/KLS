-- Phase 2D rollback: Restore original Purchase_GetAllList
DROP PROCEDURE IF EXISTS dbo.Purchase_GetAllList;

IF OBJECT_ID('dbo.Purchase_GetAllList_prev') IS NOT NULL
    EXEC sp_rename 'Purchase_GetAllList_prev', 'Purchase_GetAllList';
