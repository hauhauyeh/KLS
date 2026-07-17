SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Slice 1: allow drop-ship freight split rows to be recorded without landed-cost allocation.
-- No new table/column. This only widens existing ShipmentCharge basis constraints.
--
-- Validation examples after deploy:
--   BEGIN TRAN;
--   -- Insert/update test rows in a local scratch scenario only, then ROLLBACK.
--   ROLLBACK;

IF OBJECT_ID('dbo.ShipmentCharge', 'U') IS NULL
    THROW 51001, 'ShipmentCharge_NoLandedCost_LineBasis: dbo.ShipmentCharge not found.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.ShipmentCharge
    WHERE LineBasis = 'NO_LANDED_COST'
)
BEGIN
    PRINT 'NO_LANDED_COST rows already exist; constraints will be recreated to support them.';
END

ALTER TABLE dbo.ShipmentCharge DROP CONSTRAINT IF EXISTS CK_ShipmentCharge_FreightBasis;
GO

ALTER TABLE dbo.ShipmentCharge DROP CONSTRAINT IF EXISTS CK_ShipmentCharge_LineBasis;
GO

ALTER TABLE dbo.ShipmentCharge WITH CHECK
    ADD CONSTRAINT CK_ShipmentCharge_LineBasis
    CHECK (LineBasis IN ('BY_VOLUME','BY_WEIGHT','BY_VALUE','BY_QUANTITY','BY_DUTY_TARIFF','NO_LANDED_COST'));
GO

-- Freight per-bill row: BillBasis required (pallet/space) AND LineBasis required.
-- NO_LANDED_COST is allowed for drop-ship freight shares; allocation SPs must ignore those rows.
ALTER TABLE dbo.ShipmentCharge WITH CHECK
    ADD CONSTRAINT CK_ShipmentCharge_FreightBasis
    CHECK (ShipmentPurchaseId IS NULL
        OR ChargeType <> 'Freight'
        OR (ISNULL(BillBasis,'') IN ('BY_PALLET','BY_SPACE_PCT')
            AND ISNULL(LineBasis,'') IN ('BY_VOLUME','BY_WEIGHT','BY_VALUE','BY_QUANTITY','NO_LANDED_COST')));
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
