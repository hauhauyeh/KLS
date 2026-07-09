USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- SalesQuoteDetail: make item-only columns nullable
-- 2026-07-09: account/freight lines (LineType 'A') have no
--   ItemId / ItemUnitId / Unit, so these columns must allow NULL
--   for SalesQuote_Insert / SalesQuote_Update to persist them.
--
-- Notes:
--   * FKs FK_SalesQuoteDetail_Item (ItemId) and
--     FK_SalesQuoteDetail_ItemUnit (ItemUnitId) do NOT need to be
--     dropped -- a foreign key allows NULL values (NULLs are not
--     checked), so ALTER COLUMN ... NULL is sufficient.
--   * No indexes / default / check constraints exist on these
--     columns (verified), so nothing else needs rebuilding.
--   * Existing rows are all non-NULL, so widening to NULL is safe.
-- ============================================================

ALTER TABLE dbo.SalesQuoteDetail ALTER COLUMN ItemId INT NULL;
GO

ALTER TABLE dbo.SalesQuoteDetail ALTER COLUMN ItemUnitId INT NULL;
GO

ALTER TABLE dbo.SalesQuoteDetail ALTER COLUMN Unit NVARCHAR(50) NULL;
GO
