SET XACT_ABORT ON;
SET NOCOUNT ON;

/*
    Edge protector master-data cleanup.

    Direction:
      Keep the -B item.
      Add the bundle unit to the -B item.
      Retire the matching plain item.

    Scope:
      These six pairs have no source, temp, purchase, PO, inventory-adjustment,
      or journal references. This script does not move transactions and does
      not run RecalcQAV.
*/

DECLARE @Pairs TABLE (
    KeepBItemId INT NOT NULL,
    KeepBCode NVARCHAR(50) NOT NULL,
    RetirePlainItemId INT NOT NULL,
    RetirePlainCode NVARCHAR(50) NOT NULL,
    BundleUnit NVARCHAR(50) NOT NULL,
    MultipleToBase INT NOT NULL
);

INSERT INTO @Pairs (KeepBItemId, KeepBCode, RetirePlainItemId, RetirePlainCode, BundleUnit, MultipleToBase)
VALUES
    (76,  N'EP-12-2230-B',  75,  N'EP-12-2230',   N'bndl/60pc', 60),
    (87,  N'EP-12-2248-B',  86,  N'EP-12-2248',   N'bndl/60pc', 60),
    (100, N'EP-12-230-B',   99,  N'EP-12-230',    N'bndl/30pc', 30),
    (134, N'EP-16-2272-B',  133, N'EP-16-2272',   N'bndl/30pc', 30),
    (144, N'EP-16-248-B',   143, N'EP-16-248',    N'bndl/50pc', 50),
    (234, N'EP-C16-2084-B', 233, N'EP-C16-2084',  N'bndl/40pc', 40);

IF DB_NAME() <> 'GUS_2026'
    THROW 51300, 'Wrong database. This cleanup script is for local GUS_2026 only.', 1;

IF EXISTS (
    SELECT 1
    FROM @Pairs p
    LEFT JOIN dbo.Item keepItem ON keepItem.ItemId = p.KeepBItemId
    LEFT JOIN dbo.Item retireItem ON retireItem.ItemId = p.RetirePlainItemId
    WHERE keepItem.ItemId IS NULL
       OR retireItem.ItemId IS NULL
       OR keepItem.ItemCode <> p.KeepBCode
       OR retireItem.ItemCode <> p.RetirePlainCode
       OR keepItem.ItemType <> 'Inventory'
       OR retireItem.ItemType <> 'Inventory'
       OR keepItem.IsDeleted <> 0
       OR retireItem.IsDeleted <> 0
       OR keepItem.Inactive <> 0
       OR retireItem.Inactive <> 0
)
    THROW 51301, 'One or more item pairs are missing, inactive, deleted, non-inventory, or have unexpected item codes.', 1;

IF EXISTS (
    SELECT 1
    FROM @Pairs p
    WHERE (SELECT COUNT(*) FROM dbo.ItemUnit WHERE ItemId = p.KeepBItemId AND Inactive = 0 AND IsBaseUnit = 1 AND Unit = 'pc' AND FactorToBase = 1 AND MultipleToBase = 1) <> 1
       OR (SELECT COUNT(*) FROM dbo.ItemUnit WHERE ItemId = p.RetirePlainItemId AND Inactive = 0 AND IsBaseUnit = 1 AND Unit = 'pc' AND FactorToBase = 1 AND MultipleToBase = 1) <> 1
)
    THROW 51302, 'One or more pairs do not have exactly one active pc base unit on both items.', 1;

IF EXISTS (
    SELECT 1
    FROM @Pairs p
    WHERE EXISTS (SELECT 1 FROM dbo.SalesDetail WHERE ItemId IN (p.KeepBItemId, p.RetirePlainItemId))
       OR EXISTS (SELECT 1 FROM dbo.TempSales WHERE ItemId IN (p.KeepBItemId, p.RetirePlainItemId))
       OR EXISTS (SELECT 1 FROM dbo.TransactionJournalDetail WHERE ItemId IN (p.KeepBItemId, p.RetirePlainItemId))
       OR EXISTS (SELECT 1 FROM dbo.PurchaseDetail WHERE ItemId IN (p.KeepBItemId, p.RetirePlainItemId))
       OR EXISTS (SELECT 1 FROM dbo.TempPurchase WHERE ItemId IN (p.KeepBItemId, p.RetirePlainItemId))
       OR EXISTS (SELECT 1 FROM dbo.PurchaseOrderDetail WHERE ItemId IN (p.KeepBItemId, p.RetirePlainItemId))
       OR EXISTS (SELECT 1 FROM dbo.InventoryAdjDetail WHERE ItemId IN (p.KeepBItemId, p.RetirePlainItemId))
       OR EXISTS (SELECT 1 FROM dbo.SalesQuoteDetail WHERE ItemId IN (p.KeepBItemId, p.RetirePlainItemId))
       OR EXISTS (SELECT 1 FROM dbo.OpenBalanceInv WHERE ItemId IN (p.KeepBItemId, p.RetirePlainItemId))
)
    THROW 51303, 'One or more pairs have source, temp, quote, open-balance, journal, purchase, PO, or inventory references.', 1;

IF EXISTS (
    SELECT 1
    FROM @Pairs p
    INNER JOIN dbo.ItemUnit iu ON iu.ItemId = p.KeepBItemId
    WHERE iu.Inactive = 0
      AND (
            iu.Unit = p.BundleUnit
         OR iu.MultipleToBase = p.MultipleToBase
      )
      AND (
            iu.Unit <> p.BundleUnit
         OR iu.FactorToBase <> 1
         OR iu.MultipleToBase <> p.MultipleToBase
         OR iu.IsBaseUnit <> 0
      )
)
    THROW 51304, 'One or more kept -B items have a conflicting active bundle unit.', 1;

PRINT 'Before cleanup - pairs';
SELECT p.KeepBItemId, keepItem.ItemCode AS KeepBCode, keepItem.ItemName AS KeepBName, keepItem.SetPacking AS KeepBSetPacking, keepItem.Inactive AS KeepBInactive,
       p.RetirePlainItemId, retireItem.ItemCode AS RetirePlainCode, retireItem.ItemName AS RetirePlainName, retireItem.SetPacking AS RetirePlainSetPacking, retireItem.Inactive AS RetirePlainInactive,
       p.BundleUnit, p.MultipleToBase
FROM @Pairs p
INNER JOIN dbo.Item keepItem ON keepItem.ItemId = p.KeepBItemId
INNER JOIN dbo.Item retireItem ON retireItem.ItemId = p.RetirePlainItemId
ORDER BY p.KeepBItemId;

BEGIN TRAN;

    INSERT INTO dbo.ItemUnit (
        ItemId,
        Unit,
        FactorToBase,
        PricePercentToBase,
        IsBaseUnit,
        IsDefaultSalesUnit,
        Barcode,
        RecentCost,
        FreightCost,
        P1,
        MSRP,
        MarketPrice,
        Inactive,
        MultipleToBase,
        RecentBaseCost
    )
    SELECT
        p.KeepBItemId,
        p.BundleUnit,
        1,
        NULL,
        0,
        0,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        0,
        p.MultipleToBase,
        NULL
    FROM @Pairs p
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.ItemUnit iu
        WHERE iu.ItemId = p.KeepBItemId
          AND iu.Unit = p.BundleUnit
          AND iu.Inactive = 0
          AND iu.FactorToBase = 1
          AND iu.MultipleToBase = p.MultipleToBase
          AND iu.IsBaseUnit = 0
    );

    UPDATE keepItem
    SET SetPacking = 'pc',
        UpdatedAt = GETUTCDATE()
    FROM dbo.Item keepItem
    INNER JOIN @Pairs p ON p.KeepBItemId = keepItem.ItemId
    WHERE ISNULL(keepItem.SetPacking, '') <> 'pc';

    UPDATE retireItem
    SET Inactive = 1,
        ItemName = CASE WHEN LEFT(ISNULL(retireItem.ItemName, ''), 1) = '_' THEN retireItem.ItemName ELSE '_' + ISNULL(retireItem.ItemName, '') END,
        UpdatedAt = GETUTCDATE()
    FROM dbo.Item retireItem
    INNER JOIN @Pairs p ON p.RetirePlainItemId = retireItem.ItemId;

    IF EXISTS (
        SELECT 1
        FROM @Pairs p
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.ItemUnit iu
            WHERE iu.ItemId = p.KeepBItemId
              AND iu.Unit = p.BundleUnit
              AND iu.Inactive = 0
              AND iu.FactorToBase = 1
              AND iu.MultipleToBase = p.MultipleToBase
              AND iu.IsBaseUnit = 0
        )
    )
        THROW 51305, 'One or more bundle units are missing after insert.', 1;

    IF EXISTS (
        SELECT 1
        FROM @Pairs p
        INNER JOIN dbo.Item retireItem ON retireItem.ItemId = p.RetirePlainItemId
        WHERE retireItem.Inactive <> 1
           OR LEFT(ISNULL(retireItem.ItemName, ''), 1) <> '_'
    )
        THROW 51306, 'One or more plain items were not retired after update.', 1;

COMMIT;

PRINT 'After cleanup - kept -B items and retired plain items';
SELECT p.KeepBItemId, keepItem.ItemCode AS KeepBCode, keepItem.SetPacking AS KeepBSetPacking, keepItem.Inactive AS KeepBInactive,
       p.RetirePlainItemId, retireItem.ItemCode AS RetirePlainCode, retireItem.ItemName AS RetirePlainName, retireItem.Inactive AS RetirePlainInactive,
       p.BundleUnit, p.MultipleToBase
FROM @Pairs p
INNER JOIN dbo.Item keepItem ON keepItem.ItemId = p.KeepBItemId
INNER JOIN dbo.Item retireItem ON retireItem.ItemId = p.RetirePlainItemId
ORDER BY p.KeepBItemId;

PRINT 'After cleanup - kept -B units';
SELECT iu.ItemUnitId, iu.ItemId, i.ItemCode, iu.Unit, iu.FactorToBase, iu.MultipleToBase, iu.IsBaseUnit, iu.IsDefaultSalesUnit, iu.Inactive
FROM dbo.ItemUnit iu
INNER JOIN dbo.Item i ON i.ItemId = iu.ItemId
WHERE iu.ItemId IN (SELECT KeepBItemId FROM @Pairs)
ORDER BY iu.ItemId, iu.ItemUnitId;
