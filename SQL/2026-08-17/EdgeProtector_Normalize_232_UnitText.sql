SET XACT_ABORT ON;
SET NOCOUNT ON;

/*
    Edge protector item 232 normalization.

    Direction:
      Keep item 232 EP-C16-2060-B.
      Keep existing item/unit identity and journal identity.
      Normalize bundle unit text from BNDL to bndl/40pc.

    Scope:
      Item 232 only.
      Sales#100181 detail 319 only.
      TxId 479 journal rows remain on item 232.
      No RecalcQAV because item identity, quantities, and conversion do not change.
*/

DECLARE @ItemId INT = 232;
DECLARE @BundleItemUnitId INT = 347;
DECLARE @ExpectedItemCode NVARCHAR(50) = N'EP-C16-2060-B';
DECLARE @OldBundleUnit NVARCHAR(50) = N'BNDL';
DECLARE @NewBundleUnit NVARCHAR(50) = N'bndl/40pc';
DECLARE @ExpectedSalesNumber INT = 100181;
DECLARE @ExpectedSalesDetailId INT = 319;
DECLARE @ExpectedTxId BIGINT = 479;

IF DB_NAME() <> 'GUS_2026'
    THROW 51400, 'Wrong database. This cleanup script is for local GUS_2026 only.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Item
    WHERE ItemId = @ItemId
      AND ItemCode = @ExpectedItemCode
      AND ItemType = 'Inventory'
      AND Inactive = 0
      AND IsDeleted = 0
)
    THROW 51401, 'Item 232 is missing, inactive, deleted, non-inventory, or has unexpected item code.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ItemUnit
    WHERE ItemUnitId = @BundleItemUnitId
      AND ItemId = @ItemId
      AND Unit = @OldBundleUnit
      AND FactorToBase = 1
      AND MultipleToBase = 40
      AND IsBaseUnit = 0
      AND Inactive = 0
)
    THROW 51402, 'Expected active BNDL/40 conversion unit was not found.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.ItemUnit
    WHERE ItemId = @ItemId
      AND Unit = @NewBundleUnit
      AND ItemUnitId <> @BundleItemUnitId
      AND Inactive = 0
)
    THROW 51403, 'A different active bndl/40pc unit already exists on item 232.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SalesDetail sd
    INNER JOIN dbo.Sales s ON s.SalesId = sd.SalesId
    WHERE sd.SalesDetailId = @ExpectedSalesDetailId
      AND s.SalesNumber = @ExpectedSalesNumber
      AND sd.ItemId = @ItemId
      AND sd.ItemUnitId = @BundleItemUnitId
      AND sd.Unit = @OldBundleUnit
      AND sd.OrdQty = 252
      AND sd.ShipQty = 252
      AND sd.BillQty = 252
)
    THROW 51404, 'Expected Sales#100181 detail 319 line was not found.', 1;

IF (SELECT COUNT(*) FROM dbo.SalesDetail WHERE ItemId = @ItemId) <> 1
    THROW 51405, 'Unexpected SalesDetail reference count for item 232.', 1;

IF (
    SELECT COUNT(*)
    FROM dbo.TransactionJournalDetail
    WHERE TxId = @ExpectedTxId
      AND SourceDetailId = @ExpectedSalesDetailId
      AND ItemId = @ItemId
) <> 3
    THROW 51406, 'Expected three TxId 479 journal rows for SalesDetail 319 were not found.', 1;

PRINT 'Before normalization';
SELECT ItemId, ItemCode, ItemName, ItemType, SetPacking, Inactive, IsDeleted
FROM dbo.Item
WHERE ItemId = @ItemId;

SELECT ItemUnitId, ItemId, Unit, FactorToBase, MultipleToBase, IsBaseUnit, IsDefaultSalesUnit, Inactive
FROM dbo.ItemUnit
WHERE ItemId = @ItemId
ORDER BY ItemUnitId;

SELECT s.SalesNumber, sd.SalesDetailId, sd.ItemId, sd.ItemUnitId, sd.Unit, sd.OrdQty, sd.ShipQty, sd.BillQty, sd.UnitPrice, sd.ExtTotal, sd.FactorToBase
FROM dbo.SalesDetail sd
INNER JOIN dbo.Sales s ON s.SalesId = sd.SalesId
WHERE sd.SalesDetailId = @ExpectedSalesDetailId;

BEGIN TRAN;

    UPDATE dbo.ItemUnit
    SET Unit = @NewBundleUnit
    WHERE ItemUnitId = @BundleItemUnitId
      AND ItemId = @ItemId
      AND Unit = @OldBundleUnit
      AND FactorToBase = 1
      AND MultipleToBase = 40
      AND IsBaseUnit = 0
      AND Inactive = 0;

    IF @@ROWCOUNT <> 1
        THROW 51407, 'ItemUnit update did not affect exactly one row.', 1;

    UPDATE dbo.SalesDetail
    SET Unit = @NewBundleUnit
    WHERE SalesDetailId = @ExpectedSalesDetailId
      AND ItemId = @ItemId
      AND ItemUnitId = @BundleItemUnitId
      AND Unit = @OldBundleUnit;

    IF @@ROWCOUNT <> 1
        THROW 51408, 'SalesDetail unit update did not affect exactly one row.', 1;

    UPDATE dbo.Item
    SET SetPacking = 'pc',
        UpdatedAt = GETUTCDATE()
    WHERE ItemId = @ItemId
      AND ISNULL(SetPacking, '') <> 'pc';

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.ItemUnit
        WHERE ItemUnitId = @BundleItemUnitId
          AND ItemId = @ItemId
          AND Unit = @NewBundleUnit
          AND FactorToBase = 1
          AND MultipleToBase = 40
          AND IsBaseUnit = 0
          AND Inactive = 0
    )
        THROW 51409, 'Bundle unit was not normalized as expected.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.SalesDetail
        WHERE SalesDetailId = @ExpectedSalesDetailId
          AND ItemId = @ItemId
          AND ItemUnitId = @BundleItemUnitId
          AND Unit = @NewBundleUnit
    )
        THROW 51410, 'SalesDetail unit was not normalized as expected.', 1;

COMMIT;

PRINT 'After normalization';
SELECT ItemId, ItemCode, ItemName, ItemType, SetPacking, Inactive, IsDeleted
FROM dbo.Item
WHERE ItemId = @ItemId;

SELECT ItemUnitId, ItemId, Unit, FactorToBase, MultipleToBase, IsBaseUnit, IsDefaultSalesUnit, Inactive
FROM dbo.ItemUnit
WHERE ItemId = @ItemId
ORDER BY ItemUnitId;

SELECT s.SalesNumber, sd.SalesDetailId, sd.ItemId, sd.ItemUnitId, sd.Unit, sd.OrdQty, sd.ShipQty, sd.BillQty, sd.UnitPrice, sd.ExtTotal, sd.FactorToBase
FROM dbo.SalesDetail sd
INNER JOIN dbo.Sales s ON s.SalesId = sd.SalesId
WHERE sd.SalesDetailId = @ExpectedSalesDetailId;

SELECT tj.TxId, tj.SourceDocType, tj.SourceDocNumber, tj.TxDate, tjd.TxDetailId, tjd.SourceDetailId, a.AccountCode, tjd.ItemId, tjd.Qty, tjd.BillQty, tjd.FactorToBase, tjd.Amount
FROM dbo.TransactionJournalDetail tjd
INNER JOIN dbo.TransactionJournal tj ON tj.TxId = tjd.TxId
LEFT JOIN dbo.Account a ON a.AccountId = tjd.AccountId
WHERE tjd.TxId = @ExpectedTxId
  AND tjd.SourceDetailId = @ExpectedSalesDetailId
ORDER BY tjd.TxDetailId;
