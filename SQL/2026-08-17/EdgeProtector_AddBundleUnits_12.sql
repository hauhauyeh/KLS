SET XACT_ABORT ON;
SET NOCOUNT ON;

/*
    Edge protector bundle-unit normalization.

    Direction:
      Keep these active -B items.
      Add the missing bundle unit.
      Skip item 193 because its bundle multiple is not stated in the item name.

    Scope:
      Master data only. No source rows, journal rows, item identity, quantity,
      price, or inventory recalculation changes.
*/

DECLARE @Items TABLE (
    ItemId INT NOT NULL,
    ItemCode NVARCHAR(50) NOT NULL,
    BundleUnit NVARCHAR(50) NOT NULL,
    MultipleToBase INT NOT NULL
);

INSERT INTO @Items (ItemId, ItemCode, BundleUnit, MultipleToBase)
VALUES
    (78,  N'EP-12-2236-B',   N'bndl/60pc', 60),
    (95,  N'EP-12-2284-B',   N'bndl/30pc', 30),
    (98,  N'EP-12-2296-B',   N'bndl/30pc', 30),
    (122, N'EP-16-2236-B',   N'bndl/50pc', 50),
    (142, N'EP-16-240-B',    N'bndl/50pc', 50),
    (226, N'EP-C12-2048-B',  N'bndl/60pc', 60),
    (228, N'EP-C12-2060-B',  N'bndl/80pc', 80),
    (229, N'EP-C12-2072-B',  N'bndl/40pc', 40),
    (230, N'EP-C12-2084-B',  N'bndl/30pc', 30),
    (231, N'EP-C12-2096-B',  N'bndl/30pc', 30),
    (237, N'EP-C22-2040-B',  N'bndl/40pc', 40),
    (238, N'EP-C22-2060-B',  N'bndl/25pc', 25);

IF DB_NAME() <> 'GUS_2026'
    THROW 51500, 'Wrong database. This cleanup script is for local GUS_2026 only.', 1;

IF EXISTS (
    SELECT 1
    FROM @Items x
    LEFT JOIN dbo.Item i ON i.ItemId = x.ItemId
    WHERE i.ItemId IS NULL
       OR i.ItemCode <> x.ItemCode
       OR i.ItemType <> 'Inventory'
       OR i.Inactive <> 0
       OR i.IsDeleted <> 0
)
    THROW 51501, 'One or more target items are missing, inactive, deleted, non-inventory, or have unexpected item codes.', 1;

IF EXISTS (
    SELECT 1
    FROM @Items x
    WHERE (SELECT COUNT(*) FROM dbo.ItemUnit WHERE ItemId = x.ItemId AND Unit = 'pc' AND FactorToBase = 1 AND MultipleToBase = 1 AND IsBaseUnit = 1 AND Inactive = 0) <> 1
)
    THROW 51502, 'One or more target items do not have exactly one active pc base unit.', 1;

IF EXISTS (
    SELECT 1
    FROM @Items x
    WHERE EXISTS (SELECT 1 FROM dbo.SalesDetail WHERE ItemId = x.ItemId)
       OR EXISTS (SELECT 1 FROM dbo.TempSales WHERE ItemId = x.ItemId)
       OR EXISTS (SELECT 1 FROM dbo.TransactionJournalDetail WHERE ItemId = x.ItemId)
       OR EXISTS (SELECT 1 FROM dbo.PurchaseDetail WHERE ItemId = x.ItemId)
       OR EXISTS (SELECT 1 FROM dbo.TempPurchase WHERE ItemId = x.ItemId)
       OR EXISTS (SELECT 1 FROM dbo.PurchaseOrderDetail WHERE ItemId = x.ItemId)
       OR EXISTS (SELECT 1 FROM dbo.InventoryAdjDetail WHERE ItemId = x.ItemId)
       OR EXISTS (SELECT 1 FROM dbo.SalesQuoteDetail WHERE ItemId = x.ItemId)
       OR EXISTS (SELECT 1 FROM dbo.OpenBalanceInv WHERE ItemId = x.ItemId)
)
    THROW 51503, 'One or more target items have refs. Stop for manual review.', 1;

IF EXISTS (
    SELECT 1
    FROM @Items x
    INNER JOIN dbo.ItemUnit iu ON iu.ItemId = x.ItemId
    WHERE iu.Inactive = 0
      AND iu.IsBaseUnit = 0
)
    THROW 51504, 'One or more target items already have an active non-base unit. Stop for manual review.', 1;

PRINT 'Before bundle insert';
SELECT x.ItemId, i.ItemCode, i.ItemName, i.SetPacking, x.BundleUnit, x.MultipleToBase
FROM @Items x
INNER JOIN dbo.Item i ON i.ItemId = x.ItemId
ORDER BY x.ItemId;

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
        x.ItemId,
        x.BundleUnit,
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
        x.MultipleToBase,
        NULL
    FROM @Items x;

    UPDATE i
    SET SetPacking = 'pc',
        UpdatedAt = GETUTCDATE()
    FROM dbo.Item i
    INNER JOIN @Items x ON x.ItemId = i.ItemId
    WHERE ISNULL(i.SetPacking, '') <> 'pc';

    IF EXISTS (
        SELECT 1
        FROM @Items x
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.ItemUnit iu
            WHERE iu.ItemId = x.ItemId
              AND iu.Unit = x.BundleUnit
              AND iu.FactorToBase = 1
              AND iu.MultipleToBase = x.MultipleToBase
              AND iu.IsBaseUnit = 0
              AND iu.IsDefaultSalesUnit = 0
              AND iu.Inactive = 0
        )
    )
        THROW 51505, 'One or more bundle units were not inserted correctly.', 1;

COMMIT;

PRINT 'After bundle insert';
SELECT iu.ItemUnitId, iu.ItemId, i.ItemCode, iu.Unit, iu.FactorToBase, iu.MultipleToBase, iu.IsBaseUnit, iu.IsDefaultSalesUnit, iu.Inactive
FROM dbo.ItemUnit iu
INNER JOIN dbo.Item i ON i.ItemId = iu.ItemId
WHERE iu.ItemId IN (SELECT ItemId FROM @Items)
ORDER BY iu.ItemId, iu.ItemUnitId;
