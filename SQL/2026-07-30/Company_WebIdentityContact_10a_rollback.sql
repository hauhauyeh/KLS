SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- Rollback for Company_WebIdentityContact_10a.sql (2026-07-30).
-- Drops only the nullable web identity/contact fields added by Slice 10a.
-- Idempotent: safe to re-run. Order is reverse of the forward script.
-- =============================================================================================

IF COL_LENGTH('dbo.Company', 'WebFaviconUrl') IS NOT NULL
    ALTER TABLE dbo.Company DROP COLUMN WebFaviconUrl;
GO

IF COL_LENGTH('dbo.Company', 'WebLogoUrl') IS NOT NULL
    ALTER TABLE dbo.Company DROP COLUMN WebLogoUrl;
GO

IF COL_LENGTH('dbo.Company', 'PublicContactName') IS NOT NULL
    ALTER TABLE dbo.Company DROP COLUMN PublicContactName;
GO

IF COL_LENGTH('dbo.Company', 'PublicAddressName') IS NOT NULL
    ALTER TABLE dbo.Company DROP COLUMN PublicAddressName;
GO

IF COL_LENGTH('dbo.Company', 'BusinessHours') IS NOT NULL
    ALTER TABLE dbo.Company DROP COLUMN BusinessHours;
GO

IF COL_LENGTH('dbo.Company', 'SupportPhone') IS NOT NULL
    ALTER TABLE dbo.Company DROP COLUMN SupportPhone;
GO

IF COL_LENGTH('dbo.Company', 'SalesEmail') IS NOT NULL
    ALTER TABLE dbo.Company DROP COLUMN SalesEmail;
GO

IF COL_LENGTH('dbo.Company', 'SupportEmail') IS NOT NULL
    ALTER TABLE dbo.Company DROP COLUMN SupportEmail;
GO
