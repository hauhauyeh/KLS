-- Backfill per-bill shipment charge method after making AllocationMethod the
-- current display/source field. Safe to rerun.

UPDATE dbo.ShipmentCharge
SET AllocationMethod = LineBasis,
    UpdatedAt = ISNULL(UpdatedAt, GETUTCDATE())
WHERE ShipmentPurchaseId IS NOT NULL
  AND AllocationMethod IS NULL
  AND LineBasis IS NOT NULL;

-- Verification: should return 0.
SELECT RemainingBlankMethods = COUNT(*)
FROM dbo.ShipmentCharge
WHERE ShipmentPurchaseId IS NOT NULL
  AND AllocationMethod IS NULL
  AND LineBasis IS NOT NULL;
