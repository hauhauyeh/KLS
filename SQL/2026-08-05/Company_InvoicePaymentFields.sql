-- Company_InvoicePaymentFields.sql
-- Adds Company payment-instruction fields used by AR invoice email bodies.
-- These fields replace the old raw SystemSetting INVOICE_EMAIL_PAYMENT_INSTRUCTIONS
-- for invoice emails. Payment instructions render only when an invoice has
-- AmountDue > 0 and at least one Company payment row has usable data.

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF DB_NAME() NOT IN ('KLS_2026', 'GUS_2026')
BEGIN
    THROW 50000, 'Company_InvoicePaymentFields.sql must be run against KLS_2026 or GUS_2026.', 1;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentTitle')
    ALTER TABLE dbo.Company ADD InvoicePaymentTitle NVARCHAR(100) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentBankName')
    ALTER TABLE dbo.Company ADD InvoicePaymentBankName NVARCHAR(100) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentAccountName')
    ALTER TABLE dbo.Company ADD InvoicePaymentAccountName NVARCHAR(150) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentAccountNumber')
    ALTER TABLE dbo.Company ADD InvoicePaymentAccountNumber NVARCHAR(50) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentRoutingNumber')
    ALTER TABLE dbo.Company ADD InvoicePaymentRoutingNumber NVARCHAR(50) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentAchRoutingNumber')
    ALTER TABLE dbo.Company ADD InvoicePaymentAchRoutingNumber NVARCHAR(50) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentZelleEmail')
    ALTER TABLE dbo.Company ADD InvoicePaymentZelleEmail NVARCHAR(150) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentZellePhone')
    ALTER TABLE dbo.Company ADD InvoicePaymentZellePhone NVARCHAR(30) NULL;
GO

DELETE FROM dbo.SystemSetting
WHERE SettingKey = 'INVOICE_EMAIL_PAYMENT_INSTRUCTIONS';
GO

-- Manual Company payment setup example. Review and edit values before running.
-- UPDATE dbo.Company
-- SET InvoicePaymentTitle = 'Payment Instructions',
--     InvoicePaymentBankName = 'Example Bank',
--     InvoicePaymentAccountName = 'Example Foods Inc.',
--     InvoicePaymentAccountNumber = '123456789',
--     InvoicePaymentRoutingNumber = '111000025',
--     InvoicePaymentAchRoutingNumber = NULL,
--     InvoicePaymentZelleEmail = 'payments@example.com',
--     InvoicePaymentZellePhone = NULL
-- WHERE CompanyId = 1;
-- GO

PRINT 'Company_InvoicePaymentFields completed successfully.';
GO
