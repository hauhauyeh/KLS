SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- Rollback for ItemTariff_Phase1_Schema.sql (2026-07-23).
-- Reverses constraints, unique index, and metadata columns. Does NOT drop the table.
-- Idempotent: safe to re-run. Order is reverse of the forward script.
-- TariffRate precision was never changed by the forward script -> nothing to revert.
-- =============================================================================================

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ItemTariff_CountryCode_Alpha2')
    ALTER TABLE dbo.ItemTariff DROP CONSTRAINT CK_ItemTariff_CountryCode_Alpha2;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ItemTariff_TariffRate_NonNegative')
    ALTER TABLE dbo.ItemTariff DROP CONSTRAINT CK_ItemTariff_TariffRate_NonNegative;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ItemTariff_DutyRate_NonNegative')
    ALTER TABLE dbo.ItemTariff DROP CONSTRAINT CK_ItemTariff_DutyRate_NonNegative;
GO

IF EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'UX_ItemTariff_Item_Country' AND object_id = OBJECT_ID('dbo.ItemTariff')
)
    DROP INDEX UX_ItemTariff_Item_Country ON dbo.ItemTariff;
GO

IF COL_LENGTH('dbo.ItemTariff', 'Notes') IS NOT NULL
    ALTER TABLE dbo.ItemTariff DROP COLUMN Notes;
GO

IF COL_LENGTH('dbo.ItemTariff', 'HSNCode') IS NOT NULL
    ALTER TABLE dbo.ItemTariff DROP COLUMN HSNCode;
GO
