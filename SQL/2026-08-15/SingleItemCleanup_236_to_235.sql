SET XACT_ABORT ON;
SET NOCOUNT ON;

/*
    Single duplicate item cleanup - edge protector cleanup.

    Target duplicate:
      ItemId              236
      Base ItemUnitId      236
      Sales ItemUnitId     348

    Replacement:
      ItemId              235
      Base ItemUnitId      235
      Sales Unit           BNDL/25pc (created when missing)

    Scope:
      Move Sales#100181 / TxId 479 from target item to replacement item,
      map the historical bundle unit to replacement bundle unit,
      recalc both items, then retire the target item.
*/

DECLARE @TargetItemId INT = 236;
DECLARE @TargetBaseItemUnitId INT = 236;
DECLARE @TargetSalesItemUnitId INT = 348;
DECLARE @ReplacementItemId INT = 235;
DECLARE @ReplacementBaseItemUnitId INT = 235;
DECLARE @ReplacementSalesItemUnitId INT;

DECLARE @ExpectedSalesNumber INT = 100181;
DECLARE @ExpectedSalesDetailId INT = 321;
DECLARE @ExpectedTxId BIGINT = 479;
DECLARE @ExpectedTargetSalesUnit NVARCHAR(50) = N'BNDL';
DECLARE @ExpectedReplacementSalesUnit NVARCHAR(50) = N'BNDL/25pc';
DECLARE @ReplacementSalesUnit NVARCHAR(50);
DECLARE @TargetSalesUnit NVARCHAR(50);
DECLARE @BeginDate DATE;

DECLARE @LCloQty DECIMAL(18,6);
DECLARE @LAvgCost DECIMAL(18,6);
DECLARE @LInventoryValue DECIMAL(18,6);

IF DB_NAME() <> 'GUS_2026'
    THROW 51100, 'Wrong database. This cleanup script is for local GUS_2026 only.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.Item WHERE ItemId = @TargetItemId AND IsDeleted = 0)
    THROW 51101, 'Target item does not exist or is deleted.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.Item WHERE ItemId = @ReplacementItemId AND IsDeleted = 0)
    THROW 51102, 'Replacement item does not exist or is deleted.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ItemUnit
    WHERE ItemUnitId = @TargetBaseItemUnitId
      AND ItemId = @TargetItemId
      AND Inactive = 0
      AND IsBaseUnit = 1
)
    THROW 51103, 'Target base item unit does not exist, is inactive, or is not base unit.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ItemUnit
    WHERE ItemUnitId = @ReplacementBaseItemUnitId
      AND ItemId = @ReplacementItemId
      AND Inactive = 0
      AND IsBaseUnit = 1
)
    THROW 51104, 'Replacement base item unit does not exist, is inactive, or is not base unit.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ItemUnit
    WHERE ItemUnitId = @TargetSalesItemUnitId
      AND ItemId = @TargetItemId
      AND Inactive = 0
)
    THROW 51105, 'Target sales item unit does not exist, is inactive, or does not belong to target item.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.ItemUnit
    WHERE ItemId = @ReplacementItemId
      AND Inactive = 0
      AND (
            Unit = @ExpectedReplacementSalesUnit
         OR MultipleToBase = 25
      )
      AND (
            Unit <> @ExpectedReplacementSalesUnit
         OR ISNULL(FactorToBase, 0) <> 1
         OR ISNULL(MultipleToBase, 0) <> 25
         OR ISNULL(IsBaseUnit, 0) <> 0
      )
)
    THROW 51119, 'Replacement item has a conflicting bundle unit. Stop for manual review.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ItemUnit
    WHERE ItemId = @ReplacementItemId
      AND Unit = @ExpectedReplacementSalesUnit
      AND Inactive = 0
      AND ISNULL(FactorToBase, 0) = 1
      AND ISNULL(MultipleToBase, 0) = 25
      AND ISNULL(IsBaseUnit, 0) = 0
)
BEGIN
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
    VALUES (
        @ReplacementItemId,
        @ExpectedReplacementSalesUnit,
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
        25,
        NULL
    );
END;

SELECT @ReplacementSalesItemUnitId = ItemUnitId
FROM dbo.ItemUnit
WHERE ItemId = @ReplacementItemId
  AND Unit = @ExpectedReplacementSalesUnit
  AND Inactive = 0
  AND ISNULL(FactorToBase, 0) = 1
  AND ISNULL(MultipleToBase, 0) = 25
  AND ISNULL(IsBaseUnit, 0) = 0;

IF @ReplacementSalesItemUnitId IS NULL
    THROW 51120, 'Replacement BNDL/25pc unit could not be created or selected.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ItemUnit
    WHERE ItemUnitId = @ReplacementSalesItemUnitId
      AND ItemId = @ReplacementItemId
      AND Inactive = 0
)
    THROW 51106, 'Replacement sales item unit does not exist, is inactive, or does not belong to replacement item.', 1;

SELECT @TargetSalesUnit = Unit
FROM dbo.ItemUnit
WHERE ItemUnitId = @TargetSalesItemUnitId;

SELECT @ReplacementSalesUnit = Unit
FROM dbo.ItemUnit
WHERE ItemUnitId = @ReplacementSalesItemUnitId;

IF ISNULL(@TargetSalesUnit, '') <> @ExpectedTargetSalesUnit
    THROW 51107, 'Target sales unit text is not the expected BNDL. Stop for manual review.', 1;

IF ISNULL(@ReplacementSalesUnit, '') <> @ExpectedReplacementSalesUnit
    THROW 51118, 'Replacement sales unit text is not the expected BNDL/25pc. Stop for manual review.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.ItemUnit tu
    INNER JOIN dbo.ItemUnit ru ON ru.ItemUnitId = @ReplacementSalesItemUnitId
    WHERE tu.ItemUnitId = @TargetSalesItemUnitId
      AND (
            ISNULL(tu.FactorToBase, 0) <> ISNULL(ru.FactorToBase, 0)
         OR ISNULL(tu.MultipleToBase, 0) <> ISNULL(ru.MultipleToBase, 0)
      )
)
    THROW 51108, 'Target and replacement sales unit conversion does not match. Stop for manual review.', 1;

IF (SELECT COUNT(*) FROM dbo.SalesDetail WHERE ItemId = @TargetItemId) <> 1
    THROW 51109, 'Unexpected SalesDetail reference count for target item.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SalesDetail sd
    INNER JOIN dbo.Sales s ON s.SalesId = sd.SalesId
    WHERE sd.SalesDetailId = @ExpectedSalesDetailId
      AND s.SalesNumber = @ExpectedSalesNumber
      AND sd.ItemId = @TargetItemId
      AND sd.ItemUnitId = @TargetSalesItemUnitId
      AND sd.OrdQty = 180
      AND sd.ShipQty = 180
)
    THROW 51110, 'Expected Sales#100181 target bundle line was not found.', 1;

IF (SELECT COUNT(*) FROM dbo.TransactionJournalDetail WHERE ItemId = @TargetItemId) <> 3
    THROW 51111, 'Unexpected TransactionJournalDetail reference count for target item.', 1;

IF (SELECT COUNT(*) FROM dbo.TransactionJournalDetail WHERE TxId = @ExpectedTxId AND SourceDetailId = @ExpectedSalesDetailId AND ItemId = @TargetItemId) <> 3
    THROW 51112, 'Expected TxId 479 journal rows were not found.', 1;

IF EXISTS (SELECT 1 FROM dbo.PurchaseDetail WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.PurchaseOrderDetail WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.InventoryAdjDetail WHERE ItemId = @TargetItemId)
 OR EXISTS (SELECT 1 FROM dbo.TempSales WHERE ItemId = @TargetItemId)
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
    THROW 51113, 'Target item has unexpected references outside the approved Sales#100181 cleanup.', 1;

SELECT @BeginDate = MIN(tj.TxDate)
FROM dbo.TransactionJournalDetail tjd
INNER JOIN dbo.TransactionJournal tj ON tj.TxId = tjd.TxId
WHERE tjd.ItemId = @TargetItemId;

IF @BeginDate IS NULL
    THROW 51114, 'Could not determine recalculation begin date.', 1;

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
        ItemUnitId = @ReplacementSalesItemUnitId,
        Unit = @ReplacementSalesUnit
    WHERE SalesDetailId = @ExpectedSalesDetailId
      AND ItemId = @TargetItemId
      AND ItemUnitId = @TargetSalesItemUnitId;

    IF @@ROWCOUNT <> 1
        THROW 51115, 'SalesDetail update did not affect exactly one row.', 1;

    UPDATE dbo.TransactionJournalDetail
    SET ItemId = @ReplacementItemId
    WHERE TxId = @ExpectedTxId
      AND SourceDetailId = @ExpectedSalesDetailId
      AND ItemId = @TargetItemId;

    IF @@ROWCOUNT <> 3
        THROW 51116, 'TransactionJournalDetail update did not affect exactly three rows.', 1;

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
     OR EXISTS (SELECT 1 FROM dbo.TransactionJournalDetail WHERE ItemId = @TargetItemId)
     OR EXISTS (SELECT 1 FROM dbo.PurchaseDetail WHERE ItemId = @TargetItemId)
     OR EXISTS (SELECT 1 FROM dbo.PurchaseOrderDetail WHERE ItemId = @TargetItemId)
     OR EXISTS (SELECT 1 FROM dbo.InventoryAdjDetail WHERE ItemId = @TargetItemId)
        THROW 51117, 'Target item still has source or journal references after cleanup.', 1;

COMMIT;

PRINT 'After cleanup - items';
SELECT ItemId, ItemCode, ItemName, Inactive, IsDeleted, LCloseQty, LAvgCost, LInventoryValue
FROM dbo.Item
WHERE ItemId IN (@TargetItemId, @ReplacementItemId)
ORDER BY ItemId;

PRINT 'After cleanup - Sales#100181';
SELECT s.SalesId, s.SalesNumber, sd.SalesDetailId, sd.ItemId, i.ItemCode, sd.ItemUnitId, sd.Unit, sd.OrdQty, sd.ShipQty, sd.UnitPrice, sd.ExtTotal
FROM dbo.SalesDetail sd
INNER JOIN dbo.Sales s ON s.SalesId = sd.SalesId
INNER JOIN dbo.Item i ON i.ItemId = sd.ItemId
WHERE sd.SalesDetailId = @ExpectedSalesDetailId;

PRINT 'After cleanup - TxId 479';
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
UNION ALL SELECT 'PurchaseDetail', COUNT(*) FROM dbo.PurchaseDetail WHERE ItemId = @TargetItemId
UNION ALL SELECT 'PurchaseOrderDetail', COUNT(*) FROM dbo.PurchaseOrderDetail WHERE ItemId = @TargetItemId
UNION ALL SELECT 'InventoryAdjDetail', COUNT(*) FROM dbo.InventoryAdjDetail WHERE ItemId = @TargetItemId
UNION ALL SELECT 'ItemUnit', COUNT(*) FROM dbo.ItemUnit WHERE ItemId = @TargetItemId;
