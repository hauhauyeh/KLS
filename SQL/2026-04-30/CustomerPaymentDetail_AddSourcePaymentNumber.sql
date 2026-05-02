-- Replace SourceCustomerPaymentId with SourcePaymentNumber
-- SourceCustomerPaymentId is unstable because CustomerPaymentId changes on edit/update
-- PaymentNumber is the stable business key that survives row recreation

-- Drop old column (no data exists — 0 rows populated)
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'CustomerPaymentDetail' AND COLUMN_NAME = 'SourceCustomerPaymentId')
    ALTER TABLE dbo.CustomerPaymentDetail DROP COLUMN SourceCustomerPaymentId;

-- Add new stable column
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'CustomerPaymentDetail' AND COLUMN_NAME = 'SourcePaymentNumber')
    ALTER TABLE dbo.CustomerPaymentDetail ADD SourcePaymentNumber INT NULL;
