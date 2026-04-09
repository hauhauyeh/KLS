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

    DECLARE @AffectedSourcePayment TABLE
    (
        PaymentNumber INT PRIMARY KEY
    );

    IF EXISTS (
        SELECT 1
        FROM deleted d
        INNER JOIN dbo.CustomerPaymentDetail pd
            ON pd.SourcePaymentNumber = d.PaymentNumber
        LEFT JOIN deleted d2
            ON d2.CustomerPaymentId = pd.CustomerPaymentId
        WHERE d2.CustomerPaymentId IS NULL
    )
    OR EXISTS (
        SELECT 1
        FROM deleted d
        INNER JOIN dbo.CustomerPaymentSourceUse su
            ON su.SourcePaymentNumber = d.PaymentNumber
        LEFT JOIN deleted d2
            ON d2.CustomerPaymentId = su.CustomerPaymentId
        WHERE d2.CustomerPaymentId IS NULL
    )
    BEGIN
        RAISERROR('Cannot delete payment because it is used by another payment as source credit.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    INSERT INTO @AffectedSourcePayment(PaymentNumber)
    SELECT DISTINCT pd.SourcePaymentNumber
    FROM dbo.CustomerPaymentDetail pd
    INNER JOIN deleted d
        ON d.CustomerPaymentId = pd.CustomerPaymentId
    WHERE pd.SourcePaymentNumber IS NOT NULL;

    INSERT INTO @AffectedSourcePayment(PaymentNumber)
    SELECT DISTINCT su.SourcePaymentNumber
    FROM dbo.CustomerPaymentSourceUse su
    INNER JOIN deleted d
        ON d.CustomerPaymentId = su.CustomerPaymentId
    WHERE NOT EXISTS (
            SELECT 1
            FROM @AffectedSourcePayment a
            WHERE a.PaymentNumber = su.SourcePaymentNumber
    );

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

    DELETE su
    FROM dbo.CustomerPaymentSourceUse su
    INNER JOIN deleted d
        ON d.CustomerPaymentId = su.CustomerPaymentId;

    ;WITH SourceHeader AS
    (
        SELECT
            cp.CustomerPaymentId,
            cp.PaymentAmount,
            ISNULL(cp.AsIncome, 0) AS AsIncome,
            SourceUseAsIncome = ISNULL((
                SELECT SUM(ISNULL(su.Amount, 0))
                FROM dbo.CustomerPaymentSourceUse su
                WHERE su.CustomerPaymentId = cp.CustomerPaymentId
                  AND su.UseType = 'AsIncome'
            ), 0),
            OwnCashApplied = ISNULL((
                SELECT SUM(ISNULL(pd.PaymentApplied, 0))
                FROM dbo.CustomerPaymentDetail pd
                WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
                  AND pd.IsCreditMemo = 0
                  AND pd.SourcePaymentNumber IS NULL
            ), 0),
            CreditMemoUsed = ISNULL((
                SELECT SUM(CASE WHEN pd.PaymentApplied < 0 THEN ISNULL(pd.PaymentApplied, 0) * -1 ELSE 0 END)
                FROM dbo.CustomerPaymentDetail pd
                WHERE pd.CustomerPaymentId = cp.CustomerPaymentId
                  AND pd.IsCreditMemo = 1
            ), 0),
            ConsumedByOthers = ISNULL((
                SELECT SUM(ISNULL(pd.PaymentApplied, 0))
                FROM dbo.CustomerPaymentDetail pd
                WHERE pd.SourcePaymentNumber = cp.PaymentNumber
                  AND pd.CustomerPaymentId != cp.CustomerPaymentId
            ), 0) + ISNULL((
                SELECT SUM(ISNULL(su.Amount, 0))
                FROM dbo.CustomerPaymentSourceUse su
                WHERE su.SourcePaymentNumber = cp.PaymentNumber
                  AND su.CustomerPaymentId != cp.CustomerPaymentId
            ), 0)
        FROM dbo.CustomerPayment cp
        INNER JOIN @AffectedSourcePayment a
            ON a.PaymentNumber = cp.PaymentNumber
    )
    UPDATE cp
    SET
        PaymentApplied = sh.OwnCashApplied - sh.CreditMemoUsed,
        UnappliedAmount = sh.PaymentAmount - sh.OwnCashApplied + sh.CreditMemoUsed - (sh.AsIncome - sh.SourceUseAsIncome) - sh.ConsumedByOthers
    FROM dbo.CustomerPayment cp
    INNER JOIN SourceHeader sh
        ON sh.CustomerPaymentId = cp.CustomerPaymentId;
END
GO
