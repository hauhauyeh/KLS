-- Rollback: Remove Report_OrderGuide stored procedure
IF OBJECT_ID('dbo.Report_OrderGuide', 'P') IS NOT NULL
    DROP PROCEDURE dbo.Report_OrderGuide;
