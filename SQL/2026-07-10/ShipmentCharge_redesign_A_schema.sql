SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =====================================================================
-- ShipmentCharge redesign - Phase A (CORRECTED v2) - charge-type-driven basis
-- Marker: SCR_A_SCHEMA_V2_20260710
--
-- MODEL (Howard, 2026-07-10):
--   LandedCost = Freight + Duty/Tariff + ImportCommission (+ Other)
--
--   BillBasis  = how a charge TOTAL lands on each vendor bill. FREIGHT ONLY:
--                  BY_PALLET     -> bill share = PalletCount  / SUM(PalletCount)
--                  BY_SPACE_PCT  -> bill share = SpacePercent / 100
--                (PalletCount + SpacePercent are user-entered per-bill inputs on
--                 ShipmentPurchase and are range-checked there.) Duty/Tariff +
--                 manual charges have NO BillBasis.
--
--   LineBasis  = how a bill's charge spreads to its purchase lines:
--                  Freight              -> BY_VOLUME / BY_WEIGHT / BY_VALUE / BY_QUANTITY
--                                          (auto cascade VOLUME->WEIGHT->VALUE, user may
--                                           override to BY_QUANTITY; stores the RESOLVED basis)
--                  CustomDuty / Tariff  -> BY_DUTY_TARIFF  (value x (CustomDutyRate+TariffPercent))
--                  Manual / other       -> NULL            (user types each line's value)
--
--   Charge-type-scoped basis rules apply to NEW per-bill rows ONLY
--   (ShipmentPurchaseId IS NOT NULL). Legacy shipment-wide rows (NULL) and the
--   current app save path (also NULL scope) are EXEMPT -> stays app-compatible.
--
-- CHARGE TYPES: 9 compat values (8 current UI + ImportCommission). The canonical
-- FE/backend cutover is a later, deliberate step (not this phase). Rule groups:
--   Freight group      : Freight
--   Duty/Tariff group  : CustomDuty, Tariff
--   Manual/other group : Tax, Brokerage, PortCharges, Insurance, ImportCommission, Other
--
-- RE-BASELINE: run AFTER the one-time strip of the prior Phase-A objects (dev DB
-- had the old WithinBillBasis/SplitBasis columns; 0 per-bill rows, 0 PalletCount).
-- On a fresh DB this script stands alone. All constraints trusted (legacy rows all
-- Freight, basis NULL).
-- =====================================================================

-- 1) New columns (all NULL -> metadata-only, instant)
ALTER TABLE dbo.ShipmentCharge   ADD ShipmentPurchaseId INT          NULL;
ALTER TABLE dbo.ShipmentCharge   ADD BillBasis          VARCHAR(20)  NULL;
ALTER TABLE dbo.ShipmentCharge   ADD LineBasis          VARCHAR(20)  NULL;
ALTER TABLE dbo.ShipmentPurchase ADD PalletCount        DECIMAL(9,2) NULL;
ALTER TABLE dbo.ShipmentPurchase ADD SpacePercent       DECIMAL(5,2) NULL;
GO

-- 1b) Harden ChargeType -> NOT NULL (verified varchar(50) CI_AS; all rows non-null)
ALTER TABLE dbo.ShipmentCharge ALTER COLUMN ChargeType VARCHAR(50) NOT NULL;
GO

-- 2) Composite FK: a per-bill charge points at its membership row AND shares its ShipmentId
CREATE UNIQUE NONCLUSTERED INDEX UX_ShipmentPurchase_Id_Shipment
    ON dbo.ShipmentPurchase (ShipmentPurchaseId, ShipmentId);
GO
ALTER TABLE dbo.ShipmentCharge WITH CHECK
    ADD CONSTRAINT FK_ShipmentCharge_ShipmentPurchase
    FOREIGN KEY (ShipmentPurchaseId, ShipmentId)
    REFERENCES dbo.ShipmentPurchase (ShipmentPurchaseId, ShipmentId);
GO

-- 3) Domain CHECKs (allow NULL; enforce the value set when present)
--    ChargeType = 9 compat values (8 current UI + ImportCommission).
ALTER TABLE dbo.ShipmentCharge WITH CHECK
    ADD CONSTRAINT CK_ShipmentCharge_ChargeType
    CHECK (ChargeType IN ('Freight','CustomDuty','Tariff','Tax','Brokerage','PortCharges','Insurance','ImportCommission','Other'));

ALTER TABLE dbo.ShipmentCharge WITH CHECK
    ADD CONSTRAINT CK_ShipmentCharge_BillBasis
    CHECK (BillBasis IN ('BY_PALLET','BY_SPACE_PCT'));

ALTER TABLE dbo.ShipmentCharge WITH CHECK
    ADD CONSTRAINT CK_ShipmentCharge_LineBasis
    CHECK (LineBasis IN ('BY_VOLUME','BY_WEIGHT','BY_VALUE','BY_QUANTITY','BY_DUTY_TARIFF'));
GO

-- 3b) Input CHECKs for user-entered per-bill freight split inputs
ALTER TABLE dbo.ShipmentPurchase WITH CHECK
    ADD CONSTRAINT CK_ShipmentPurchase_PalletCount
    CHECK (PalletCount IS NULL OR PalletCount >= 0);

ALTER TABLE dbo.ShipmentPurchase WITH CHECK
    ADD CONSTRAINT CK_ShipmentPurchase_SpacePercent
    CHECK (SpacePercent IS NULL OR SpacePercent BETWEEN 0 AND 100);
GO

-- 4) Scope + charge-type-scoped basis rules (per-bill rows only; legacy NULL exempt)
ALTER TABLE dbo.ShipmentCharge WITH CHECK
    ADD CONSTRAINT CK_ShipmentCharge_Scope
    CHECK (ShipmentPurchaseId IS NOT NULL OR ShipmentId IS NOT NULL);

-- Freight per-bill row: BillBasis required (pallet/space) AND LineBasis required (freight set).
-- ISNULL(...) wrap makes a NULL basis evaluate FALSE (reject), not UNKNOWN (which a CHECK passes) -
-- that is how "required on new" is enforced for Freight.
ALTER TABLE dbo.ShipmentCharge WITH CHECK
    ADD CONSTRAINT CK_ShipmentCharge_FreightBasis
    CHECK (ShipmentPurchaseId IS NULL
        OR ChargeType <> 'Freight'
        OR (ISNULL(BillBasis,'') IN ('BY_PALLET','BY_SPACE_PCT')
            AND ISNULL(LineBasis,'') IN ('BY_VOLUME','BY_WEIGHT','BY_VALUE','BY_QUANTITY')));

-- Duty/Tariff per-bill row: no BillBasis; LineBasis must be BY_DUTY_TARIFF.
-- ISNULL(LineBasis,'') forces a NULL LineBasis to FALSE (reject), not UNKNOWN (pass).
ALTER TABLE dbo.ShipmentCharge WITH CHECK
    ADD CONSTRAINT CK_ShipmentCharge_DutyTariffBasis
    CHECK (ShipmentPurchaseId IS NULL
        OR ChargeType NOT IN ('CustomDuty','Tariff')
        OR (BillBasis IS NULL AND ISNULL(LineBasis,'') = 'BY_DUTY_TARIFF'));

-- Manual/other per-bill row: no BillBasis, no LineBasis (value entered per line)
ALTER TABLE dbo.ShipmentCharge WITH CHECK
    ADD CONSTRAINT CK_ShipmentCharge_ManualBasis
    CHECK (ShipmentPurchaseId IS NULL
        OR ChargeType NOT IN ('Tax','Brokerage','PortCharges','Insurance','ImportCommission','Other')
        OR (BillBasis IS NULL AND LineBasis IS NULL));
GO

-- 5) One charge per (shipment, bill, type) for new per-bill rows
CREATE UNIQUE NONCLUSTERED INDEX UX_ShipmentCharge_Ship_Bill_Type
    ON dbo.ShipmentCharge (ShipmentId, ShipmentPurchaseId, ChargeType)
    WHERE ShipmentPurchaseId IS NOT NULL;
GO

-- 6) Validation. Expect: named=11, fk_cols=2, untrusted=0, legacy_rows=53, ct_notnull=1, newcols=5
SELECT
    named      = (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.ShipmentCharge') AND name IN (
                      'CK_ShipmentCharge_ChargeType','CK_ShipmentCharge_BillBasis','CK_ShipmentCharge_LineBasis',
                      'CK_ShipmentCharge_Scope','CK_ShipmentCharge_FreightBasis','CK_ShipmentCharge_DutyTariffBasis',
                      'CK_ShipmentCharge_ManualBasis'))
               + (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.ShipmentPurchase') AND name IN (
                      'CK_ShipmentPurchase_PalletCount','CK_ShipmentPurchase_SpacePercent'))
               + (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID('dbo.ShipmentCharge')  AND name='FK_ShipmentCharge_ShipmentPurchase')
               + (SELECT COUNT(*) FROM sys.indexes      WHERE object_id=OBJECT_ID('dbo.ShipmentCharge')         AND name='UX_ShipmentCharge_Ship_Bill_Type'),
    fk_cols    = (SELECT COUNT(*) FROM sys.foreign_key_columns WHERE constraint_object_id=OBJECT_ID('FK_ShipmentCharge_ShipmentPurchase')),
    untrusted  = (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.ShipmentCharge') AND is_not_trusted=1)
               + (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.ShipmentPurchase') AND is_not_trusted=1)
               + (SELECT COUNT(*) FROM sys.foreign_keys     WHERE parent_object_id=OBJECT_ID('dbo.ShipmentCharge') AND is_not_trusted=1),
    legacy_rows= (SELECT COUNT(*) FROM dbo.ShipmentCharge),
    ct_notnull = (SELECT 1 - is_nullable FROM sys.columns WHERE object_id=OBJECT_ID('dbo.ShipmentCharge') AND name='ChargeType'),
    newcols    = (SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID('dbo.ShipmentCharge')   AND name IN ('ShipmentPurchaseId','BillBasis','LineBasis'))
               + (SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID('dbo.ShipmentPurchase') AND name IN ('PalletCount','SpacePercent'));
GO
