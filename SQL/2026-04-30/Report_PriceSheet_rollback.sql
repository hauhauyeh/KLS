-- Rollback: Restore Report_PriceSheet from _prev version
IF OBJECT_ID('dbo.Report_PriceSheet', 'P') IS NOT NULL
    DROP PROCEDURE dbo.Report_PriceSheet;

EXEC sp_rename 'Report_PriceSheet_prev', 'Report_PriceSheet';
