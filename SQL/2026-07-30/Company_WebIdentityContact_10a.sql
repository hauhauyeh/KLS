SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- Slice 10a - Company web identity/contact fields
-- Date : 2026-07-30
-- Plan : plan-kls-web-client-experience-slice10-db-backed-company-identity.md
-- Idempotent: safe to re-run. Rollback: Company_WebIdentityContact_10a_rollback.sql
--
-- Adds nullable web-only fields to dbo.Company. Existing report/PDF logo behavior remains
-- unchanged: Company.HasLogo and the backend [NotMapped] Company.LogoUrl are not modified.
-- =============================================================================================

IF COL_LENGTH('dbo.Company', 'SupportEmail') IS NULL
    ALTER TABLE dbo.Company ADD SupportEmail nvarchar(100) NULL;
GO

IF COL_LENGTH('dbo.Company', 'SalesEmail') IS NULL
    ALTER TABLE dbo.Company ADD SalesEmail nvarchar(100) NULL;
GO

IF COL_LENGTH('dbo.Company', 'SupportPhone') IS NULL
    ALTER TABLE dbo.Company ADD SupportPhone nvarchar(50) NULL;
GO

IF COL_LENGTH('dbo.Company', 'BusinessHours') IS NULL
    ALTER TABLE dbo.Company ADD BusinessHours nvarchar(500) NULL;
GO

IF COL_LENGTH('dbo.Company', 'PublicAddressName') IS NULL
    ALTER TABLE dbo.Company ADD PublicAddressName nvarchar(100) NULL;
GO

IF COL_LENGTH('dbo.Company', 'PublicContactName') IS NULL
    ALTER TABLE dbo.Company ADD PublicContactName nvarchar(100) NULL;
GO

IF COL_LENGTH('dbo.Company', 'WebLogoUrl') IS NULL
    ALTER TABLE dbo.Company ADD WebLogoUrl nvarchar(255) NULL;
GO

IF COL_LENGTH('dbo.Company', 'WebFaviconUrl') IS NULL
    ALTER TABLE dbo.Company ADD WebFaviconUrl nvarchar(255) NULL;
GO
