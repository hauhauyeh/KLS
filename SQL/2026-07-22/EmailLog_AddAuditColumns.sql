-- EmailLog_AddAuditColumns.sql
-- Phase 1 of the EmailLog system-wide audit plan.
-- Adds nullable audit columns to dbo.EmailLog. Purely additive and backward
-- compatible: existing rows get NULLs, and dbo.EmailLog_GetAllList uses an
-- explicit SELECT list so it is unaffected until Phase 5.
--
-- Deploy BEFORE the Phase 2 backend model change (EF includes every mapped
-- property in its INSERT, so the columns must exist first).

SET QUOTED_IDENTIFIER ON;
GO

-- Workflow classification -----------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'EmailCategory')
    ALTER TABLE dbo.EmailLog ADD EmailCategory NVARCHAR(50) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'EmailType')
    ALTER TABLE dbo.EmailLog ADD EmailType NVARCHAR(50) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'FromEmail')
    ALTER TABLE dbo.EmailLog ADD FromEmail NVARCHAR(255) NULL;
GO

-- Document identity -----------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'DocumentType')
    ALTER TABLE dbo.EmailLog ADD DocumentType NVARCHAR(50) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'DocumentId')
    ALTER TABLE dbo.EmailLog ADD DocumentId INT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'DocumentNumber')
    ALTER TABLE dbo.EmailLog ADD DocumentNumber NVARCHAR(50) NULL;
GO

-- Related entity (non-document emails) ----------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'RelatedEntityType')
    ALTER TABLE dbo.EmailLog ADD RelatedEntityType NVARCHAR(50) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'RelatedEntityId')
    ALTER TABLE dbo.EmailLog ADD RelatedEntityId INT NULL;
GO

-- Message + attribution -------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'Subject')
    ALTER TABLE dbo.EmailLog ADD Subject NVARCHAR(200) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'RequestedBy')
    ALTER TABLE dbo.EmailLog ADD RequestedBy INT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'Source')
    ALTER TABLE dbo.EmailLog ADD Source NVARCHAR(30) NULL;
GO

-- Provider acceptance ---------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'Provider')
    ALTER TABLE dbo.EmailLog ADD Provider NVARCHAR(50) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'ProviderMessageId')
    ALTER TABLE dbo.EmailLog ADD ProviderMessageId NVARCHAR(255) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'DeliveryStatus')
    ALTER TABLE dbo.EmailLog ADD DeliveryStatus NVARCHAR(30) NULL;
GO

-- Reserved for future webhook/lifecycle tracking (no writer in this effort) ----
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.EmailLog') AND name = 'LastDeliveryEventAt')
    ALTER TABLE dbo.EmailLog ADD LastDeliveryEventAt DATETIME NULL;
GO

PRINT 'EmailLog_AddAuditColumns completed successfully.';
GO
