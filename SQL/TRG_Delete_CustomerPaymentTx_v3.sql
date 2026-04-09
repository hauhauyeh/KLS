SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.TRG_Delete_CustomerPaymentTx', 'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_Delete_CustomerPaymentTx;

IF OBJECT_ID('dbo.TRG_Delete_CustomerPaymentTx_prev', 'TR') IS NOT NULL
    DROP TRIGGER dbo.TRG_Delete_CustomerPaymentTx_prev;
GO

CREATE TRIGGER [dbo].[TRG_Delete_CustomerPaymentTx]
ON [dbo].[CustomerPayment]
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerPaymentId INT;
    DECLARE @CustomerPaymentNumber INT;
    DECLARE @VendorPaymentId INT;
    DECLARE @RowNum INT = 1;
    DECLARE @MaxRow INT;

    IF EXISTS (
        SELECT 1
        FROM deleted d
        INNER JOIN dbo.CustomerPaymentDetail pd
            ON pd.SourcePaymentNumber = d.PaymentNumber
        LEFT JOIN deleted d2
            ON d2.CustomerPaymentId = pd.CustomerPaymentId
        WHERE d2.CustomerPaymentId IS NULL
    )
    BEGIN
        RAISERROR('Cannot delete payment because it is used by another payment as source credit.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    UPDATE cp
    SET cp.UnappliedAmount = ISNULL(cp.UnappliedAmount, 0) + x.RestoreAmount
    FROM dbo.CustomerPayment cp
    INNER JOIN (
        SELECT pd.SourcePaymentNumber, SUM(ISNULL(pd.PaymentApplied, 0)) AS RestoreAmount
        FROM dbo.CustomerPaymentDetail pd
        INNER JOIN deleted d
            ON d.CustomerPaymentId = pd.CustomerPaymentId
        WHERE pd.SourcePaymentNumber IS NOT NULL
        GROUP BY pd.SourcePaymentNumber
    ) x
        ON x.SourcePaymentNumber = cp.PaymentNumber;

    DECLARE @PmtDelete TABLE (
        AutoId INT IDENTITY(1,1) PRIMARY KEY,
        CustomerPaymentId INT,
        CustomerPaymentNumber INT,
        VendorPaymentId INT
    );

    INSERT INTO @PmtDelete (CustomerPaymentId, CustomerPaymentNumber, VendorPaymentId)
    SELECT CustomerPaymentId, PaymentNumber, VendorPaymentId
    FROM deleted;

    SELECT @MaxRow = COUNT(AutoId) FROM @PmtDelete;

    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT
            @CustomerPaymentId = CustomerPaymentId,
            @CustomerPaymentNumber = CustomerPaymentNumber,
            @VendorPaymentId = VendorPaymentId
        FROM @PmtDelete
        WHERE AutoId = @RowNum;

        EXEC dbo.CustomerPayment_UpdateSales @CustomerPaymentId, 1;

        DELETE FROM dbo.Sales
        WHERE SalesId IN (
            SELECT SalesId
            FROM dbo.CustomerPaymentDetail
            WHERE CustomerPaymentId = @CustomerPaymentId
              AND IsCreditMemo = 1
        )
          AND AmountDue = SalesTotal;

        DELETE FROM dbo.Sales
        WHERE SalesId IN (
            SELECT SalesId
            FROM dbo.CustomerPaymentDetail
            WHERE CustomerPaymentId = @CustomerPaymentId
              AND IsCCFee = 1
        );

        DELETE FROM dbo.CustomerPayment
        WHERE CustomerPaymentId = @CustomerPaymentId;

        DELETE FROM dbo.TransactionJournal
        WHERE SourceDocType IN ('Customer Payment', 'Customer Refund', 'Other Incoming Payment')
          AND SourceDocNumber = @CustomerPaymentNumber;

        IF @VendorPaymentId IS NOT NULL
        BEGIN
            DELETE FROM dbo.VendorPayment
            WHERE VendorPaymentId = @VendorPaymentId;
        END

        SET @RowNum += 1;
    END
END
GO
