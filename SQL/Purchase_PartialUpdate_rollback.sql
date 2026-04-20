IF OBJECT_ID('dbo.Purchase_PartialUpdate', 'P') IS NOT NULL
    DROP PROCEDURE dbo.Purchase_PartialUpdate;
GO

IF OBJECT_ID('dbo.Purchase_PartialUpdate_prev', 'P') IS NOT NULL
BEGIN
    EXEC sp_rename 'dbo.Purchase_PartialUpdate_prev', 'Purchase_PartialUpdate';
END
GO
