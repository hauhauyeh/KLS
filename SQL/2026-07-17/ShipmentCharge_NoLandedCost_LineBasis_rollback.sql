SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Rollback for Slice 1.
-- This restores the prior ShipmentCharge LineBasis/FreightBasis constraints.
-- It is intentionally guarded because the old constraints reject NO_LANDED_COST rows.

IF OBJECT_ID('dbo.ShipmentCharge', 'U') IS NULL
    THROW 51011, 'ShipmentCharge_NoLandedCost_LineBasis rollback: dbo.ShipmentCharge not found.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.ShipmentCharge
    WHERE LineBasis = 'NO_LANDED_COST'
)
    THROW 51012, 'Rollback blocked: ShipmentCharge has NO_LANDED_COST rows. Remove or convert them before restoring old constraints.', 1;

ALTER TABLE dbo.ShipmentCharge DROP CONSTRAINT IF EXISTS CK_ShipmentCharge_FreightBasis;
GO

ALTER TABLE dbo.ShipmentCharge DROP CONSTRAINT IF EXISTS CK_ShipmentCharge_LineBasis;
GO

ALTER TABLE dbo.ShipmentCharge WITH CHECK
    ADD CONSTRAINT CK_ShipmentCharge_LineBasis
    CHECK (LineBasis IN ('BY_VOLUME','BY_WEIGHT','BY_VALUE','BY_QUANTITY','BY_DUTY_TARIFF'));
GO

ALTER TABLE dbo.ShipmentCharge WITH CHECK
    ADD CONSTRAINT CK_ShipmentCharge_FreightBasis
    CHECK (ShipmentPurchaseId IS NULL
        OR ChargeType <> 'Freight'
        OR (ISNULL(BillBasis,'') IN ('BY_PALLET','BY_SPACE_PCT')
            AND ISNULL(LineBasis,'') IN ('BY_VOLUME','BY_WEIGHT','BY_VALUE','BY_QUANTITY')));
GO

SELECT
    ConstraintName = cc.name,
    cc.definition,
    cc.is_not_trusted
FROM sys.check_constraints cc
WHERE cc.parent_object_id = OBJECT_ID('dbo.ShipmentCharge')
  AND cc.name IN ('CK_ShipmentCharge_LineBasis', 'CK_ShipmentCharge_FreightBasis')
ORDER BY cc.name;
GO
