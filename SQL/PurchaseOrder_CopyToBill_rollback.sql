IF OBJECT_ID('dbo.PurchaseOrder_CopyToBill', 'P') IS NOT NULL
    DROP PROCEDURE dbo.PurchaseOrder_CopyToBill;
GO

IF OBJECT_ID('dbo.PurchaseOrder_CopyToBill_prev', 'P') IS NOT NULL
BEGIN
    EXEC sp_rename 'dbo.PurchaseOrder_CopyToBill_prev', 'PurchaseOrder_CopyToBill';
END
GO
