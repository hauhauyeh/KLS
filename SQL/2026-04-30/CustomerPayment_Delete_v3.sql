SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.CustomerPayment_Delete', 'P') IS NOT NULL
BEGIN
    IF OBJECT_ID('dbo.CustomerPayment_Delete_prev', 'P') IS NOT NULL
        DROP PROCEDURE dbo.CustomerPayment_Delete_prev;

    EXEC sp_rename 'dbo.CustomerPayment_Delete', 'CustomerPayment_Delete_prev';
END
GO

CREATE PROCEDURE [dbo].[CustomerPayment_Delete]
    @CustomerPaymentId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.CustomerPayment
        WHERE CustomerPaymentId = @CustomerPaymentId
    )
    BEGIN
        RAISERROR('Customer payment not found.', 16, 1);
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM dbo.CustomerPayment
        WHERE CustomerPaymentId = @CustomerPaymentId
          AND IsLocked = 1
    )
    BEGIN
        RAISERROR('Locked payment cannot be deleted.', 16, 1);
        RETURN;
    END

    DELETE FROM dbo.CustomerPayment
    WHERE CustomerPaymentId = @CustomerPaymentId;
END
GO
