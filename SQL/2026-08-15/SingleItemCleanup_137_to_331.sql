SET XACT_ABORT ON;
SET NOCOUNT ON;

/*
    Single duplicate item cleanup - pilot edge protector cleanup.

    Target duplicate:
      ItemId     137
      ItemUnitId 137

    Replacement:
      ItemId     331
      ItemUnitId 340

    Scope:
      Move Sales#100027 / TxId 128 from target item to replacement item,
      recalc both items, then retire the target item.
*/

DECLARE @TargetItemId INT = 137;
DECLARE @TargetItemUnitId INT = 137;
DECLARE @ReplacementItemId INT = 331;
DECLARE @ReplacementItemUnitId INT = 340;

DECLARE @ExpectedSalesNumber INT = 100027;
DECLARE @ExpectedSalesDetailId INT = 43;
DECLARE @ExpectedTxId BIGINT = 128;
DECLARE @ReplacementUnit NVARCHAR(50);
DECLARE @TargetUnit NVARCHAR(50);
DECLARE @BeginDate DATE;

DECLARE @LCloQty DECIMAL(18,6);
DECLARE @LAvgCost DECIMAL(18,6);
DECLARE @LInventoryValue DECIMAL(18,6);

IF DB_NAME() <> 'GUS_2026'
    THROW 51000, 'Wrong database. This cleanup script is for local GUS_2026 only.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.Item WHERE ItemId = @TargetItemId AND IsDeleted = 0)
    THROW 51001, 'Target item does not exist or is deleted.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.Item WHERE ItemId = @ReplacementItemId AND IsDeleted = 0)
    THROW 51002, 'Replacement item does not exist or is deleted.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ItemUnit
    WHERE ItemUnitId = @TargetItemUnitId
      AND ItemId = @TargetItemId
      AND Inactive = 0
)
    THROW 51003, 'Target item unit does not exist, is inactive, or does not belong to target item.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ItemUnit
    WHERE ItemUnitId = @ReplacementItemUnitId
      AND ItemId = @ReplacementItemId
      AND Inactive = 0
)
    THROW 51004, 'Replacement item unit does not exist, is inactive, or does not belong to replacement item.', 1;

SELECT @TargetUnit = Unit
FROM dbo.ItemUnit
WHERE ItemUnitId = @TargetItemUnitId;

SELECT @ReplacementUnit = Unit
FROM dbo.ItemUnit
WHERE ItemUnitId = @ReplacementItemUnitId;

IF ISNULL(@TargetUnit, '') <> ISNULL(@ReplacementUnit, '')
    THROW 51005, 'Target and replacement units do not match. Stop for manual review.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.ItemUnit tu
    INNER JOIN dbo.ItemUnit ru ON ru.ItemUnitId = @ReplacementItemUnitId
    WHERE tu.ItemUnitId = @TargetItemUnitId
      AND (
            ISNULL(tu.FactorToBase, 0) <> ISNULL(ru.FactorToBase, 0)
         OR ISNULL(tu.MultipleToBase, 0) <> ISNULL(ru.MultipleToBase, 0)
      )
)
    THROW 51006, 'Target and replacement unit conversion does not match. Stop for manual review.', 1;

IF (SELECT COUNT(*) FROM dbo.SalesDetail WHERE ItemId = @TargetItemId) <> 1
    THROW 51007, 'Unexpected SalesDetail reference count for target item.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SalesDetail sd
    INNER JOIN dbo.Sales s ON s.SalesId = sd.SalesId
    WHERE sd.SalesDetailId = @ExpectedSalesDetailId
      AND s.SalesNumber = @ExpectedSalesNumber
      AND sd.ItemId = @TargetItemId
      AND sd.ItemUnitId = @TargetItemUnitId
      AND sd.Unit = @TargetUnit
)
    THROW 51008, 'Expected Sales#100027 target line was not found.', 1;

IF (SELECT COUNT(*) FROM dbo.TransactionJournalDetail WHERE ItemId = @TargetItemId) <> 3
    THROW 51009, 'Unexpected TransactionJournalDetail reference count for target item.', 1;

IF (SELECT COUNT(*) FROM dbo.TransactionJournalDetail WHERE TxId = @ExpectedTxId AND SourceDetailId = @ExpectedSalesDetailId AND ItemId = @TargetItemId) <> 3
    THROW 51010, 'Expected TxId 128 journal rows were not found.', 1;

IF (SELECT COUNT(*) FROM dbo.TempSales WHERE ItemId = @TargetItemId) <> 1
    THROW 51016, 'Unexpected TempSales reference count for target item.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.TempSales
    WHERE SalesId = 28
      AND SalesDetailId = @ExpectedSalesDetailId
      AND ItemId = @TargetItemId
      AND ItemUnitId = @TargetItemUnitId
      AND Unit = @TargetUnit
)
    THROW 51017, 'Expected Sales#100027 TempSales target line was not found.', 1;

IF EXISTS (SELECT 1 FROM dbo.PurchaseDetail WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.PurchaseOrderDetail WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.InventoryAdjDetail WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.TempPurchase WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.SalesQuoteDetail WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.OpenBalanceInv WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.ItemImage WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.ItemNameDetail WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.ItemReview WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.ItemTariff WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.MarketItemMap WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.MarketOrderItem WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.PromotionItem WHERE ItemId = @TargetItemId)
    THROW 51011, 'Target item has unexpected references outside the approved Sales#100027 cleanup.', 1;

SELECT @BeginDate = MIN(tj.TxDate)
FROM dbo.TransactionJournalDetail tjd
INNER JOIN dbo.TransactionJournal tj ON tj.TxId = tjd.TxId
WHERE tjd.ItemId = @TargetItemId;

IF @BeginDate IS NULL
    THROW 51012, 'Could not determine recalculation begin date.', 1;

PRINT 'Before cleanup - items';
SELECT ItemId, ItemCode, ItemName, Inactive, IsDeleted, LCloseQty, LAvgCost, LInventoryValue
FROM dbo.Item
WHERE ItemId IN (@TargetItemId, @ReplacementItemId)
ORDER BY ItemId;

PRINT 'Before cleanup - target references';
SELECT 'SalesDetail' AS Ref, COUNT(*) AS Cnt FROM dbo.SalesDetail WHERE ItemId = @TargetItemId
UNION ALL SELECT 'TransactionJournalDetail', COUNT(*) FROM dbo.TransactionJournalDetail WHERE ItemId = @TargetItemId
UNION ALL SELECT 'PurchaseDetail', COUNT(*) FROM dbo.PurchaseDetail WHERE ItemId = @TargetItemId
UNION ALL SELECT 'PurchaseOrderDetail', COUNT(*) FROM dbo.PurchaseOrderDetail WHERE ItemId = @TargetItemId
UNION ALL SELECT 'InventoryAdjDetail', COUNT(*) FROM dbo.InventoryAdjDetail WHERE ItemId = @TargetItemId;

BEGIN TRAN;

    UPDATE dbo.SalesDetail
    SET ItemId = @ReplacementItemId,
        ItemUnitId = @ReplacementItemUnitId,
        Unit = @ReplacementUnit
    WHERE SalesDetailId = @ExpectedSalesDetailId
      AND ItemId = @TargetItemId
      AND ItemUnitId = @TargetItemUnitId;

    IF @@ROWCOUNT <> 1
        THROW 51013, 'SalesDetail update did not affect exactly one row.', 1;

    UPDATE dbo.TempSales
    SET ItemId = @ReplacementItemId,
        ItemUnitId = @ReplacementItemUnitId,
        Unit = @ReplacementUnit
    WHERE SalesId = 28
      AND SalesDetailId = @ExpectedSalesDetailId
      AND ItemId = @TargetItemId
      AND ItemUnitId = @TargetItemUnitId;

    IF @@ROWCOUNT <> 1
        THROW 51018, 'TempSales update did not affect exactly one row.', 1;

    UPDATE dbo.TransactionJournalDetail
    SET ItemId = @ReplacementItemId
    WHERE TxId = @ExpectedTxId
      AND SourceDetailId = @ExpectedSalesDetailId
      AND ItemId = @TargetItemId;

    IF @@ROWCOUNT <> 3
        THROW 51014, 'TransactionJournalDetail update did not affect exactly three rows.', 1;

    EXEC dbo.RecalcQAV @TargetItemId, @BeginDate, @LCloQty OUTPUT, @LAvgCost OUTPUT, @LInventoryValue OUTPUT;

    IF @LCloQty = 0 SET @LCloQty = NULL;
    IF @LAvgCost = 0 SET @LAvgCost = NULL;
    IF @LInventoryValue = 0 SET @LInventoryValue = NULL;

    UPDATE dbo.Item
    SET LCloseQty = @LCloQty,
        LAvgCost = @LAvgCost,
        LInventoryValue = @LInventoryValue,
        UpdatedAt = GETUTCDATE()
    WHERE ItemId = @TargetItemId;

    SET @LCloQty = NULL;
    SET @LAvgCost = NULL;
    SET @LInventoryValue = NULL;

    EXEC dbo.RecalcQAV @ReplacementItemId, @BeginDate, @LCloQty OUTPUT, @LAvgCost OUTPUT, @LInventoryValue OUTPUT;

    IF @LCloQty = 0 SET @LCloQty = NULL;
    IF @LAvgCost = 0 SET @LAvgCost = NULL;
    IF @LInventoryValue = 0 SET @LInventoryValue = NULL;

    UPDATE dbo.Item
    SET LCloseQty = @LCloQty,
        LAvgCost = @LAvgCost,
        LInventoryValue = @LInventoryValue,
        UpdatedAt = GETUTCDATE()
    WHERE ItemId = @ReplacementItemId;

    UPDATE dbo.Item
    SET Inactive = 1,
        ItemName = CASE WHEN LEFT(ISNULL(ItemName, ''), 1) = '_' THEN ItemName ELSE '_' + ISNULL(ItemName, '') END,
        UpdatedAt = GETUTCDATE()
    WHERE ItemId = @TargetItemId;

    IF EXISTS (SELECT 1 FROM dbo.SalesDetail WHERE ItemId = @TargetItemId)
     OR EXISTS (SELECT 1 FROM dbo.TempSales WHERE ItemId = @TargetItemId)
     OR EXISTS (SELECT 1 FROM dbo.TransactionJournalDetail WHERE ItemId = @TargetItemId)
     OR EXISTS (SELECT 1 FROM dbo.PurchaseDetail WHERE ItemId = @TargetItemId)
     OR EXISTS (SELECT 1 FROM dbo.PurchaseOrderDetail WHERE ItemId = @TargetItemId)
     OR EXISTS (SELECT 1 FROM dbo.InventoryAdjDetail WHERE ItemId = @TargetItemId)
        THROW 51015, 'Target item still has source or journal references after cleanup.', 1;

COMMIT;

PRINT 'After cleanup - items';
SELECT ItemId, ItemCode, ItemName, Inactive, IsDeleted, LCloseQty, LAvgCost, LInventoryValue
FROM dbo.Item
WHERE ItemId IN (@TargetItemId, @ReplacementItemId)
ORDER BY ItemId;

PRINT 'After cleanup - Sales#100027';
SELECT s.SalesId, s.SalesNumber, sd.SalesDetailId, sd.ItemId, i.ItemCode, sd.ItemUnitId, sd.Unit, sd.OrdQty, sd.ShipQty, sd.UnitPrice, sd.ExtTotal
FROM dbo.SalesDetail sd
INNER JOIN dbo.Sales s ON s.SalesId = sd.SalesId
INNER JOIN dbo.Item i ON i.ItemId = sd.ItemId
WHERE sd.SalesDetailId = @ExpectedSalesDetailId;

PRINT 'After cleanup - TxId 128';
SELECT tj.TxId, tj.SourceDocType, tj.SourceDocNumber, tj.TxDate, tjd.TxDetailId, tjd.SourceDetailId, a.AccountCode, tjd.ItemId, i.ItemCode, tjd.Qty, tjd.BillQty, tjd.FactorToBase, tjd.Amount, tjd.CrDeAmount
FROM dbo.TransactionJournalDetail tjd
INNER JOIN dbo.TransactionJournal tj ON tj.TxId = tjd.TxId
LEFT JOIN dbo.Account a ON a.AccountId = tjd.AccountId
INNER JOIN dbo.Item i ON i.ItemId = tjd.ItemId
WHERE tjd.TxId = @ExpectedTxId
  AND tjd.SourceDetailId = @ExpectedSalesDetailId
ORDER BY tjd.TxDetailId;

PRINT 'After cleanup - target references';
SELECT 'SalesDetail' AS Ref, COUNT(*) AS Cnt FROM dbo.SalesDetail WHERE ItemId = @TargetItemId
UNION ALL SELECT 'TransactionJournalDetail', COUNT(*) FROM dbo.TransactionJournalDetail WHERE ItemId = @TargetItemId
UNION ALL SELECT 'TempSales', COUNT(*) FROM dbo.TempSales WHERE ItemId = @TargetItemId
UNION ALL SELECT 'PurchaseDetail', COUNT(*) FROM dbo.PurchaseDetail WHERE ItemId = @TargetItemId
UNION ALL SELECT 'PurchaseOrderDetail', COUNT(*) FROM dbo.PurchaseOrderDetail WHERE ItemId = @TargetItemId
UNION ALL SELECT 'InventoryAdjDetail', COUNT(*) FROM dbo.InventoryAdjDetail WHERE ItemId = @TargetItemId
UNION ALL SELECT 'ItemUnit', COUNT(*) FROM dbo.ItemUnit WHERE ItemId = @TargetItemId;
