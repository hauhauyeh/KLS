-- Rollback: Remove Report_SalesHistory stored procedure
IF OBJECT_ID('dbo.Report_SalesHistory', 'P') IS NOT NULL
    DROP PROCEDURE dbo.Report_SalesHistory;
