USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- ROLLBACK of SalesQuoteDetail_NullableItemColumns.sql
-- Restores ItemId / ItemUnitId / Unit to NOT NULL.
--
-- WARNING: this will FAIL if any account/freight line (LineType
--   'A', NULL ItemId) already exists in SalesQuoteDetail. Remove
--   or convert those rows first, otherwise the ALTER errors with
--   "Cannot insert the value NULL".
-- ============================================================

ALTER TABLE dbo.SalesQuoteDetail ALTER COLUMN ItemId INT NOT NULL;
GO

ALTER TABLE dbo.SalesQuoteDetail ALTER COLUMN ItemUnitId INT NOT NULL;
GO

ALTER TABLE dbo.SalesQuoteDetail ALTER COLUMN Unit NVARCHAR(50) NOT NULL;
GO
