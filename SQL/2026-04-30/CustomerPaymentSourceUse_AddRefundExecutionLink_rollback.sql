IF COL_LENGTH('dbo.CustomerPaymentSourceUse', 'RefundedAt') IS NOT NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentSourceUse
    DROP COLUMN RefundedAt;
END
GO

IF COL_LENGTH('dbo.CustomerPaymentSourceUse', 'RefundPaymentId') IS NOT NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentSourceUse
    DROP COLUMN RefundPaymentId;
END
GO
