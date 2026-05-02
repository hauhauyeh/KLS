SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.CustomerPayment_Delete', 'P') IS NOT NULL
    DROP PROCEDURE dbo.CustomerPayment_Delete;
GO

IF OBJECT_ID('dbo.CustomerPayment_Delete_prev', 'P') IS NOT NULL
BEGIN
    EXEC sp_rename 'dbo.CustomerPayment_Delete_prev', 'CustomerPayment_Delete';
END
GO
