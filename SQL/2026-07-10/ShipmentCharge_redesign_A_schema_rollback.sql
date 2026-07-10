SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =====================================================================
-- ROLLBACK - ShipmentCharge redesign Phase A (CORRECTED v2)
-- Marker: SCR_A_SCHEMA_V2_20260710_ROLLBACK
-- GUARDED: aborts if any per-bill charge (ShipmentPurchaseId NOT NULL) or
-- PalletCount / SpacePercent data exists, so rollback can never silently drop
-- entered data. Guard + all DROPs are ONE batch (no GO) so RETURN prevents drops.
-- Reverse order: indexes -> constraints -> FK -> columns -> revert ChargeType.
-- Requires SQL Server 2016+ (DROP ... IF EXISTS).
-- =====================================================================

IF EXISTS (SELECT 1 FROM dbo.ShipmentCharge      WHERE ShipmentPurchaseId IS NOT NULL)
   OR EXISTS (SELECT 1 FROM dbo.ShipmentPurchase WHERE PalletCount  IS NOT NULL)
   OR EXISTS (SELECT 1 FROM dbo.ShipmentPurchase WHERE SpacePercent IS NOT NULL)
BEGIN
    RAISERROR('ABORT rollback: per-bill ShipmentCharge rows and/or PalletCount/SpacePercent data exist. Migrate/clear them before rolling back Phase A.', 16, 1);
    RETURN;
END

DROP INDEX IF EXISTS UX_ShipmentCharge_Ship_Bill_Type ON dbo.ShipmentCharge;

ALTER TABLE dbo.ShipmentPurchase DROP CONSTRAINT IF EXISTS CK_ShipmentPurchase_SpacePercent;
ALTER TABLE dbo.ShipmentPurchase DROP CONSTRAINT IF EXISTS CK_ShipmentPurchase_PalletCount;

ALTER TABLE dbo.ShipmentCharge DROP CONSTRAINT IF EXISTS CK_ShipmentCharge_ManualBasis;
ALTER TABLE dbo.ShipmentCharge DROP CONSTRAINT IF EXISTS CK_ShipmentCharge_DutyTariffBasis;
ALTER TABLE dbo.ShipmentCharge DROP CONSTRAINT IF EXISTS CK_ShipmentCharge_FreightBasis;
ALTER TABLE dbo.ShipmentCharge DROP CONSTRAINT IF EXISTS CK_ShipmentCharge_Scope;
ALTER TABLE dbo.ShipmentCharge DROP CONSTRAINT IF EXISTS CK_ShipmentCharge_LineBasis;
ALTER TABLE dbo.ShipmentCharge DROP CONSTRAINT IF EXISTS CK_ShipmentCharge_BillBasis;
ALTER TABLE dbo.ShipmentCharge DROP CONSTRAINT IF EXISTS CK_ShipmentCharge_ChargeType;

ALTER TABLE dbo.ShipmentCharge DROP CONSTRAINT IF EXISTS FK_ShipmentCharge_ShipmentPurchase;
DROP INDEX IF EXISTS UX_ShipmentPurchase_Id_Shipment ON dbo.ShipmentPurchase;

ALTER TABLE dbo.ShipmentCharge   DROP COLUMN IF EXISTS LineBasis;
ALTER TABLE dbo.ShipmentCharge   DROP COLUMN IF EXISTS BillBasis;
ALTER TABLE dbo.ShipmentCharge   DROP COLUMN IF EXISTS ShipmentPurchaseId;
ALTER TABLE dbo.ShipmentPurchase DROP COLUMN IF EXISTS SpacePercent;
ALTER TABLE dbo.ShipmentPurchase DROP COLUMN IF EXISTS PalletCount;

-- Restore the PRE-Phase-A nullable state (ChargeType was verified is_nullable=1)
ALTER TABLE dbo.ShipmentCharge   ALTER COLUMN ChargeType VARCHAR(50) NULL;
GO
