SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.TRG_Delete_CustomerPaymentTx', 'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_Delete_CustomerPaymentTx;
GO

IF OBJECT_ID('dbo.TRG_Delete_CustomerPaymentTx_prev', 'TR') IS NOT NULL
BEGIN
    EXEC sp_rename 'dbo.TRG_Delete_CustomerPaymentTx_prev', 'TRG_Delete_CustomerPaymentTx';
END
GO
