-- Company_InvoicePaymentFields_rollback.sql
-- Drops Company payment-instruction fields added by Company_InvoicePaymentFields.sql.
--
-- The deploy script deletes SystemSetting INVOICE_EMAIL_PAYMENT_INSTRUCTIONS.
-- This rollback does not restore that old setting value automatically. If Howard
-- wants the old raw payment-instruction setting preserved, capture and restore it
-- manually before/after deployment as appropriate.

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF DB_NAME() NOT IN ('KLS_2026', 'GUS_2026')
BEGIN
    THROW 50000, 'Company_InvoicePaymentFields_rollback.sql must be run against KLS_2026 or GUS_2026.', 1;
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentZellePhone')
    ALTER TABLE dbo.Company DROP COLUMN InvoicePaymentZellePhone;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentZelleEmail')
    ALTER TABLE dbo.Company DROP COLUMN InvoicePaymentZelleEmail;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentAchRoutingNumber')
    ALTER TABLE dbo.Company DROP COLUMN InvoicePaymentAchRoutingNumber;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentRoutingNumber')
    ALTER TABLE dbo.Company DROP COLUMN InvoicePaymentRoutingNumber;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentAccountNumber')
    ALTER TABLE dbo.Company DROP COLUMN InvoicePaymentAccountNumber;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentAccountName')
    ALTER TABLE dbo.Company DROP COLUMN InvoicePaymentAccountName;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentBankName')
    ALTER TABLE dbo.Company DROP COLUMN InvoicePaymentBankName;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Company') AND name = 'InvoicePaymentTitle')
    ALTER TABLE dbo.Company DROP COLUMN InvoicePaymentTitle;
GO

PRINT 'Company_InvoicePaymentFields_rollback completed successfully.';
GO
