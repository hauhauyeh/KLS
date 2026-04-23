IF COL_LENGTH('dbo.CustomerPaymentDetail', 'RefundPaymentId') IS NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentDetail
    ADD RefundPaymentId INT NULL;
END
GO

IF COL_LENGTH('dbo.CustomerPaymentDetail', 'RefundedAt') IS NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentDetail
    ADD RefundedAt DATETIME NULL;
END
GO
