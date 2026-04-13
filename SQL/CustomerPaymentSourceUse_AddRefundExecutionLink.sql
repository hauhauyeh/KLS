IF COL_LENGTH('dbo.CustomerPaymentSourceUse', 'RefundPaymentId') IS NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentSourceUse
    ADD RefundPaymentId INT NULL;
END
GO

IF COL_LENGTH('dbo.CustomerPaymentSourceUse', 'RefundedAt') IS NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentSourceUse
    ADD RefundedAt DATETIME NULL;
END
GO
