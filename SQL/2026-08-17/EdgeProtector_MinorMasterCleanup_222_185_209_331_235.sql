SET XACT_ABORT ON;
SET NOCOUNT ON;

/*
    Edge protector minor master-data cleanup.

    Scope:
      SetPacking = pc for items 222, 185, 209, 331, 235.
      Normalize bundle unit display text where conversion is already correct.
      Update Sales#100181 detail 321 unit text because it uses item 235 unit 352.

    No item identity, quantity, price, journal, or recalculation changes.
*/

IF DB_NAME() <> 'GUS_2026'
    THROW 51600, 'Wrong database. This cleanup script is for local GUS_2026 only.', 1;

IF EXISTS (
    SELECT 1
    FROM (VALUES
        (222, N'EP-22540'),
        (185, N'EP-225-2236'),
        (209, N'EP-225-260'),
        (331, N'EP-16-236'),
        (235, N'EP-C16-2096')
    ) x(ItemId, ItemCode)
    LEFT JOIN dbo.Item i ON i.ItemId = x.ItemId
    WHERE i.ItemId IS NULL
       OR i.ItemCode <> x.ItemCode
       OR i.ItemType <> 'Inventory'
       OR i.Inactive <> 0
       OR i.IsDeleted <> 0
)
    THROW 51601, 'One or more target items are missing, inactive, deleted, non-inventory, or have unexpected item codes.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.ItemUnit WHERE ItemUnitId = 350 AND ItemId = 185 AND Unit = 'BNDL/35PC' AND MultipleToBase = 35 AND FactorToBase = 1 AND IsBaseUnit = 0 AND Inactive = 0)
    THROW 51602, 'Expected item 185 bundle unit was not found.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.ItemUnit WHERE ItemUnitId = 351 AND ItemId = 209 AND Unit = 'BNDL/35PC' AND MultipleToBase = 35 AND FactorToBase = 1 AND IsBaseUnit = 0 AND Inactive = 0)
    THROW 51603, 'Expected item 209 bundle unit was not found.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.ItemUnit WHERE ItemUnitId = 352 AND ItemId = 235 AND Unit = 'BNDL/25pc' AND MultipleToBase = 25 AND FactorToBase = 1 AND IsBaseUnit = 0 AND Inactive = 0)
    THROW 51604, 'Expected item 235 bundle unit was not found.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.ItemUnit WHERE ItemUnitId = 349 AND ItemId = 331 AND Unit = 'BNDL' AND MultipleToBase = 60 AND FactorToBase = 1 AND IsBaseUnit = 0 AND Inactive = 0)
    THROW 51605, 'Expected item 331 bundle unit was not found.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SalesDetail sd
    INNER JOIN dbo.Sales s ON s.SalesId = sd.SalesId
    WHERE sd.SalesDetailId = 321
      AND s.SalesNumber = 100181
      AND sd.ItemId = 235
      AND sd.ItemUnitId = 352
      AND sd.Unit = 'BNDL/25pc'
)
    THROW 51606, 'Expected Sales#100181 detail 321 item 235 bundle line was not found.', 1;

PRINT 'Before cleanup';
SELECT ItemId, ItemCode, SetPacking
FROM dbo.Item
WHERE ItemId IN (222,185,209,331,235)
ORDER BY ItemId;

SELECT ItemUnitId, ItemId, Unit, FactorToBase, MultipleToBase, IsBaseUnit, IsDefaultSalesUnit, Inactive
FROM dbo.ItemUnit
WHERE ItemId IN (222,185,209,331,235)
ORDER BY ItemId, ItemUnitId;

BEGIN TRAN;

    UPDATE dbo.Item
    SET SetPacking = 'pc',
        UpdatedAt = GETUTCDATE()
    WHERE ItemId IN (222,185,209,331,235)
      AND ISNULL(SetPacking, '') <> 'pc';

    UPDATE dbo.ItemUnit
    SET Unit = 'bndl/35pc'
    WHERE ItemUnitId IN (350,351)
      AND Unit = 'BNDL/35PC'
      AND FactorToBase = 1
      AND MultipleToBase = 35
      AND IsBaseUnit = 0
      AND Inactive = 0;

    IF @@ROWCOUNT <> 2
        THROW 51607, '35pc bundle unit text update did not affect exactly two rows.', 1;

    UPDATE dbo.ItemUnit
    SET Unit = 'bndl/25pc'
    WHERE ItemUnitId = 352
      AND ItemId = 235
      AND Unit = 'BNDL/25pc'
      AND FactorToBase = 1
      AND MultipleToBase = 25
      AND IsBaseUnit = 0
      AND Inactive = 0;

    IF @@ROWCOUNT <> 1
        THROW 51608, '25pc bundle unit text update did not affect exactly one row.', 1;

    UPDATE dbo.SalesDetail
    SET Unit = 'bndl/25pc'
    WHERE SalesDetailId = 321
      AND ItemId = 235
      AND ItemUnitId = 352
      AND Unit = 'BNDL/25pc';

    IF @@ROWCOUNT <> 1
        THROW 51609, 'SalesDetail 321 unit text update did not affect exactly one row.', 1;

    UPDATE dbo.ItemUnit
    SET Unit = 'bndl/60pc'
    WHERE ItemUnitId = 349
      AND ItemId = 331
      AND Unit = 'BNDL'
      AND FactorToBase = 1
      AND MultipleToBase = 60
      AND IsBaseUnit = 0
      AND Inactive = 0;

    IF @@ROWCOUNT <> 1
        THROW 51610, '60pc bundle unit text update did not affect exactly one row.', 1;

COMMIT;

PRINT 'After cleanup';
SELECT ItemId, ItemCode, SetPacking
FROM dbo.Item
WHERE ItemId IN (222,185,209,331,235)
ORDER BY ItemId;

SELECT ItemUnitId, ItemId, Unit, FactorToBase, MultipleToBase, IsBaseUnit, IsDefaultSalesUnit, Inactive
FROM dbo.ItemUnit
WHERE ItemId IN (222,185,209,331,235)
ORDER BY ItemId, ItemUnitId;

SELECT s.SalesNumber, sd.SalesDetailId, sd.ItemId, sd.ItemUnitId, sd.Unit
FROM dbo.SalesDetail sd
INNER JOIN dbo.Sales s ON s.SalesId = sd.SalesId
WHERE sd.SalesDetailId IN (43,294,321)
ORDER BY sd.SalesDetailId;
