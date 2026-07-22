-- EmailLog_AddAuditColumns_rollback.sql
-- Reverts EmailLog_AddAuditColumns.sql by dropping the added audit columns.
-- Safe only before Phase 2+ code that reads/writes these columns is deployed.

SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'LastDeliveryEventAt')
    ALTER TABLE dbo.EmailLog DROP COLUMN LastDeliveryEventAt;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'DeliveryStatus')
    ALTER TABLE dbo.EmailLog DROP COLUMN DeliveryStatus;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'ProviderMessageId')
    ALTER TABLE dbo.EmailLog DROP COLUMN ProviderMessageId;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'Provider')
    ALTER TABLE dbo.EmailLog DROP COLUMN Provider;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'Source')
    ALTER TABLE dbo.EmailLog DROP COLUMN Source;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'RequestedBy')
    ALTER TABLE dbo.EmailLog DROP COLUMN RequestedBy;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'Subject')
    ALTER TABLE dbo.EmailLog DROP COLUMN Subject;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'RelatedEntityId')
    ALTER TABLE dbo.EmailLog DROP COLUMN RelatedEntityId;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'RelatedEntityType')
    ALTER TABLE dbo.EmailLog DROP COLUMN RelatedEntityType;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'DocumentNumber')
    ALTER TABLE dbo.EmailLog DROP COLUMN DocumentNumber;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'DocumentId')
    ALTER TABLE dbo.EmailLog DROP COLUMN DocumentId;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'DocumentType')
    ALTER TABLE dbo.EmailLog DROP COLUMN DocumentType;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'FromEmail')
    ALTER TABLE dbo.EmailLog DROP COLUMN FromEmail;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'EmailType')
    ALTER TABLE dbo.EmailLog DROP COLUMN EmailType;
GO
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'EmailCategory')
    ALTER TABLE dbo.EmailLog DROP COLUMN EmailCategory;
GO

PRINT 'EmailLog_AddAuditColumns_rollback completed successfully.';
GO
