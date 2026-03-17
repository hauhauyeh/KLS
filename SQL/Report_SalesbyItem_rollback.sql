-- Rollback: Restore Report_SalesbyItem from _prev version
IF OBJECT_ID('dbo.Report_SalesbyItem', 'P') IS NOT NULL
    DROP PROCEDURE dbo.Report_SalesbyItem;

EXEC sp_rename 'Report_SalesbyItem_prev', 'Report_SalesbyItem';
