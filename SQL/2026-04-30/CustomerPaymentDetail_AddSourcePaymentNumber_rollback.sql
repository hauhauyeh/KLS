-- Rollback: restore SourceCustomerPaymentId, drop SourcePaymentNumber

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'CustomerPaymentDetail' AND COLUMN_NAME = 'SourcePaymentNumber')
    ALTER TABLE dbo.CustomerPaymentDetail DROP COLUMN SourcePaymentNumber;

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'CustomerPaymentDetail' AND COLUMN_NAME = 'SourceCustomerPaymentId')
    ALTER TABLE dbo.CustomerPaymentDetail ADD SourceCustomerPaymentId INT NULL;
