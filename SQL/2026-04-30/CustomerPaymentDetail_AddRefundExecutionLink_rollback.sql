IF COL_LENGTH('dbo.CustomerPaymentDetail', 'RefundedAt') IS NOT NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentDetail
    DROP COLUMN RefundedAt;
END
GO

IF COL_LENGTH('dbo.CustomerPaymentDetail', 'RefundPaymentId') IS NOT NULL
BEGIN
    ALTER TABLE dbo.CustomerPaymentDetail
    DROP COLUMN RefundPaymentId;
END
GO
