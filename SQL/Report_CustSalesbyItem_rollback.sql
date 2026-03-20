-- Rollback: Remove Report_CustSalesbyItem stored procedure
IF OBJECT_ID('dbo.Report_CustSalesbyItem', 'P') IS NOT NULL
    DROP PROCEDURE dbo.Report_CustSalesbyItem;
