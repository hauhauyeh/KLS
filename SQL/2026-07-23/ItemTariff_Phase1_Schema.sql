SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- Tariff Phase 1 - ItemTariff schema hardening
-- Date : 2026-07-23
-- Plan : plan/plan-tariff-phase-1-schema-and-seed.md
-- Idempotent: safe to re-run. Rollback: ItemTariff_Phase1_Schema_rollback.sql
--
-- Precheck (2026-07-23, KLS-2026): ItemTariff has PK + FK only, 0 rows,
--   CountryCode char(2), DutyRate dec(9,6), TariffRate dec(9,4).
--
-- NOTE: TariffRate is INTENTIONALLY left at dec(9,4) to match the line columns
--   PurchaseDetail.TariffPercent / TempPurchase.TariffPercent (both dec(9,4)).
--   A more precise setup value would truncate on defaulting and cause spurious
--   DIFFERENT results in the later allocation precheck. Do not widen it.
-- =============================================================================================

-- 1. Metadata columns -------------------------------------------------------------------------
IF COL_LENGTH('dbo.ItemTariff', 'HSNCode') IS NULL
    ALTER TABLE dbo.ItemTariff ADD HSNCode varchar(20) NULL;
GO

IF COL_LENGTH('dbo.ItemTariff', 'Notes') IS NULL
    ALTER TABLE dbo.ItemTariff ADD Notes varchar(500) NULL;
GO

-- 2. TariffRate precision - intentionally unchanged (see header). No ALTER here.

-- 3. Enforce one current-rate row per item/country --------------------------------------------
-- Safety guard: refuse to build the unique index if duplicates already exist
-- (0 rows in KLS-2026 today, but other environments are not assumed clean).
IF EXISTS (
    SELECT 1
    FROM   dbo.ItemTariff
    GROUP BY ItemId, CountryCode
    HAVING COUNT(*) > 1
)
    THROW 50000, 'ItemTariff has duplicate ItemId/CountryCode rows. Resolve them before creating UX_ItemTariff_Item_Country.', 1;
GO

IF NOT EXISTS (
    SELECT 1
    FROM   sys.indexes
    WHERE  name = 'UX_ItemTariff_Item_Country'
      AND  object_id = OBJECT_ID('dbo.ItemTariff')
)
    CREATE UNIQUE INDEX UX_ItemTariff_Item_Country
        ON dbo.ItemTariff (ItemId, CountryCode);
GO

-- 4. Non-negative rate checks -----------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ItemTariff_DutyRate_NonNegative')
    ALTER TABLE dbo.ItemTariff WITH CHECK
        ADD CONSTRAINT CK_ItemTariff_DutyRate_NonNegative
        CHECK (DutyRate IS NULL OR DutyRate >= 0);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ItemTariff_TariffRate_NonNegative')
    ALTER TABLE dbo.ItemTariff WITH CHECK
        ADD CONSTRAINT CK_ItemTariff_TariffRate_NonNegative
        CHECK (TariffRate IS NULL OR TariffRate >= 0);
GO

-- 5. CountryCode must be uppercase ISO alpha-2 (A-Z only). char(2) pads short
--    values with a space, which the pattern rejects, so a 1-char code fails too.
--    Safe to add now (0 rows). In a dirty environment WITH CHECK will fail-fast.
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ItemTariff_CountryCode_Alpha2')
    ALTER TABLE dbo.ItemTariff WITH CHECK
        ADD CONSTRAINT CK_ItemTariff_CountryCode_Alpha2
        CHECK (CountryCode NOT LIKE '%[^A-Z]%');
GO
