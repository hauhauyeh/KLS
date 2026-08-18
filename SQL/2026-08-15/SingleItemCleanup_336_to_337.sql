SET XACT_ABORT ON;
SET NOCOUNT ON;

/*
    Single duplicate item cleanup - non-inventory edge protector cleanup.

    Restored-state target:
      ItemId          336
      ItemCode        EP-C16-2072-B
      Sales ItemUnit  345 / BNDL

    Replacement to create:
      ItemId          337
      ItemCode        EP-C16-2072-B
      Base unit       pc
      Sales unit      bndl/30pc

    Scope:
      Rename target item code to EP-C16-2072-B-1, create replacement item
      337 using the original item code, move Sales#100181 detail 320 and the
      matching @ISALE journal row, then retire target item 336.

    This pair is NonInventory, so there are no @COGS/@INV rows and no
    inventory recalculation is needed.
*/

DECLARE @TargetItemId INT = 336;
DECLARE @TargetSalesItemUnitId INT = 345;
DECLARE @ReplacementItemId INT = 337;
DECLARE @ReplacementBaseItemUnitId INT;
DECLARE @ReplacementSalesItemUnitId INT;

DECLARE @ReplacementItemCode NVARCHAR(50) = N'EP-C16-2072-B';
DECLARE @RetiredTargetItemCode NVARCHAR(50) = N'EP-C16-2072-B-1';
DECLARE @ExpectedSalesNumber INT = 100181;
DECLARE @ExpectedSalesDetailId INT = 320;
DECLARE @ExpectedTxId BIGINT = 479;
DECLARE @ExpectedTargetSalesUnit NVARCHAR(50) = N'BNDL';
DECLARE @ExpectedReplacementBaseUnit NVARCHAR(50) = N'pc';
DECLARE @ExpectedReplacementSalesUnit NVARCHAR(50) = N'bndl/30pc';
DECLARE @ReplacementSalesUnit NVARCHAR(50);
DECLARE @TargetSalesUnit NVARCHAR(50);

IF DB_NAME() <> 'GUS_2026'
    THROW 51200, 'Wrong database. This cleanup script is for local GUS_2026 only.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.Item
    WHERE ItemId = @TargetItemId
      AND ItemCode = @ReplacementItemCode
      AND IsDeleted = 0
      AND ItemType = 'NonInventory'
)
    THROW 51201, 'Target item does not exist, has unexpected code, is deleted, or is not NonInventory.', 1;

IF EXISTS (SELECT 1 FROM dbo.Item WHERE ItemId = @ReplacementItemId)
    THROW 51202, 'Replacement item id already exists. Stop for manual review.', 1;

IF EXISTS (SELECT 1 FROM dbo.Item WHERE ItemCode = @RetiredTargetItemCode AND ItemId <> @TargetItemId)
    THROW 51203, 'Retired target item code already exists on another item. Stop for manual review.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ItemUnit
    WHERE ItemUnitId = @TargetSalesItemUnitId
      AND ItemId = @TargetItemId
      AND Unit = @ExpectedTargetSalesUnit
      AND Inactive = 0
)
    THROW 51204, 'Target sales item unit does not exist, is inactive, or does not belong to target item.', 1;

SELECT @TargetSalesUnit = Unit
FROM dbo.ItemUnit
WHERE ItemUnitId = @TargetSalesItemUnitId;

IF ISNULL(@TargetSalesUnit, '') <> @ExpectedTargetSalesUnit
    THROW 51205, 'Target sales unit text is not the expected BNDL. Stop for manual review.', 1;

IF (SELECT COUNT(*) FROM dbo.SalesDetail WHERE ItemId = @TargetItemId) <> 1
    THROW 51206, 'Unexpected SalesDetail reference count for target item.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SalesDetail sd
    INNER JOIN dbo.Sales s ON s.SalesId = sd.SalesId
    WHERE sd.SalesDetailId = @ExpectedSalesDetailId
      AND s.SalesNumber = @ExpectedSalesNumber
      AND sd.ItemId = @TargetItemId
      AND sd.ItemUnitId = @TargetSalesItemUnitId
      AND sd.OrdQty = 288
      AND sd.ShipQty = 288
)
    THROW 51207, 'Expected Sales#100181 target bundle line was not found.', 1;

IF (SELECT COUNT(*) FROM dbo.TransactionJournalDetail WHERE ItemId = @TargetItemId) <> 1
    THROW 51208, 'Unexpected TransactionJournalDetail reference count for target item.', 1;

IF (
    SELECT COUNT(*)
    FROM dbo.TransactionJournalDetail tjd
    INNER JOIN dbo.Account a ON a.AccountId = tjd.AccountId
    WHERE tjd.TxId = @ExpectedTxId
      AND tjd.SourceDetailId = @ExpectedSalesDetailId
      AND tjd.ItemId = @TargetItemId
      AND a.AccountCode = '@ISALE'
) <> 1
    THROW 51209, 'Expected TxId 479 @ISALE journal row was not found.', 1;

IF EXISTS (SELECT 1 FROM dbo.TransactionJournalDetail tjd INNER JOIN dbo.Account a ON a.AccountId = tjd.AccountId WHERE tjd.ItemId = @TargetItemId AND a.AccountCode IN ('@COGS', '@INV'))
    THROW 51210, 'Target item has inventory journal rows. Use inventory cleanup path instead.', 1;

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
    THROW 51211, 'Target item has unexpected references outside the approved Sales#100181 cleanup.', 1;

PRINT 'Before cleanup - items';
SELECT ItemId, ItemCode, ItemName, ItemType, SetPacking, BaseUnitId, Inactive, IsDeleted
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

    UPDATE dbo.Item
    SET ItemCode = @RetiredTargetItemCode,
        UpdatedAt = GETUTCDATE()
    WHERE ItemId = @TargetItemId
      AND ItemCode = @ReplacementItemCode;

    IF @@ROWCOUNT <> 1
        THROW 51212, 'Target item code rename did not affect exactly one row.', 1;

    SET IDENTITY_INSERT dbo.Item ON;

    INSERT INTO dbo.Item (
        ItemId, ItemType, ItemCode, ItemName, ItemName2, ItemSearchTag, ItemLongDesc, ItemBoxDesc, ItemBrand,
        SetPacking, PackSize, BaseUnitId, CategoryId, StorageId, PreferredVendorId, PaletteFactor,
        SaftyInventory, ActualSaftyInventory, RefillInventory, IsWeightItem, IsMetricWeight, IsMetricDimension,
        IsVolumeManual, CaseWeight, CaseLength, CaseWidth, CaseHeight, CaseVolumeInCubicFeet,
        CaseVolumeInCubicMeter, LCloseQty, LAvgCost, LInventoryValue, FutureQty, TodayOpenInventory,
        ExpiryDate, IncomeAccountId, ExpenseAccountId, COGSAccountId, InventoryAccountId, Inactive,
        IsDeleted, IsTaxable, IsHRTaxable, IsHighlighted, IsCostChange, IsImport, Last3M, M0, M1, M2,
        M3, M4, M5, M6, YTD, YTDSalesPercent, TCost1, TCost2, NCost1, NCost2, CreatedAt, UpdatedAt
    )
    SELECT
        @ReplacementItemId, ItemType, @ReplacementItemCode, ItemName, ItemName2, ItemSearchTag, ItemLongDesc, ItemBoxDesc, ItemBrand,
        @ExpectedReplacementBaseUnit, PackSize, NULL, CategoryId, StorageId, PreferredVendorId, PaletteFactor,
        SaftyInventory, ActualSaftyInventory, RefillInventory, IsWeightItem, IsMetricWeight, IsMetricDimension,
        IsVolumeManual, CaseWeight, CaseLength, CaseWidth, CaseHeight, CaseVolumeInCubicFeet,
        CaseVolumeInCubicMeter, NULL, NULL, NULL, NULL, NULL,
        ExpiryDate, IncomeAccountId, ExpenseAccountId, COGSAccountId, InventoryAccountId, 0,
        0, IsTaxable, IsHRTaxable, IsHighlighted, IsCostChange, IsImport, NULL, NULL, NULL, NULL,
        NULL, NULL, NULL, NULL, NULL, NULL, TCost1, TCost2, NCost1, NCost2, GETUTCDATE(), GETUTCDATE()
    FROM dbo.Item
    WHERE ItemId = @TargetItemId;

    IF @@ROWCOUNT <> 1
        THROW 51213, 'Replacement item insert did not affect exactly one row.', 1;

    SET IDENTITY_INSERT dbo.Item OFF;

    INSERT INTO dbo.ItemUnit (
        ItemId, Unit, FactorToBase, PricePercentToBase, IsBaseUnit, IsDefaultSalesUnit,
        Barcode, RecentCost, FreightCost, P1, MSRP, MarketPrice, Inactive, MultipleToBase, RecentBaseCost
    )
    VALUES (
        @ReplacementItemId, @ExpectedReplacementBaseUnit, 1, NULL, 1, 1,
        NULL, NULL, NULL, NULL, NULL, NULL, 0, 1, NULL
    );

    SET @ReplacementBaseItemUnitId = SCOPE_IDENTITY();

    INSERT INTO dbo.ItemUnit (
        ItemId, Unit, FactorToBase, PricePercentToBase, IsBaseUnit, IsDefaultSalesUnit,
        Barcode, RecentCost, FreightCost, P1, MSRP, MarketPrice, Inactive, MultipleToBase, RecentBaseCost
    )
    VALUES (
        @ReplacementItemId, @ExpectedReplacementSalesUnit, 1, NULL, 0, 0,
        NULL, NULL, NULL, NULL, NULL, NULL, 0, 30, NULL
    );

    SET @ReplacementSalesItemUnitId = SCOPE_IDENTITY();

    UPDATE dbo.Item
    SET BaseUnitId = @ReplacementBaseItemUnitId
    WHERE ItemId = @ReplacementItemId;

    SELECT @ReplacementSalesUnit = Unit
    FROM dbo.ItemUnit
    WHERE ItemUnitId = @ReplacementSalesItemUnitId
      AND ItemId = @ReplacementItemId
      AND Inactive = 0
      AND FactorToBase = 1
      AND MultipleToBase = 30
      AND IsBaseUnit = 0;

    IF ISNULL(@ReplacementSalesUnit, '') <> @ExpectedReplacementSalesUnit
        THROW 51214, 'Replacement sales unit was not created as expected.', 1;

    UPDATE dbo.SalesDetail
    SET ItemId = @ReplacementItemId,
        ItemUnitId = @ReplacementSalesItemUnitId,
        Unit = @ReplacementSalesUnit
    WHERE SalesDetailId = @ExpectedSalesDetailId
      AND ItemId = @TargetItemId
      AND ItemUnitId = @TargetSalesItemUnitId;

    IF @@ROWCOUNT <> 1
        THROW 51215, 'SalesDetail update did not affect exactly one row.', 1;

    UPDATE tjd
    SET ItemId = @ReplacementItemId
    FROM dbo.TransactionJournalDetail tjd
    INNER JOIN dbo.Account a ON a.AccountId = tjd.AccountId
    WHERE tjd.TxId = @ExpectedTxId
      AND tjd.SourceDetailId = @ExpectedSalesDetailId
      AND tjd.ItemId = @TargetItemId
      AND a.AccountCode = '@ISALE';

    IF @@ROWCOUNT <> 1
        THROW 51216, 'TransactionJournalDetail update did not affect exactly one @ISALE row.', 1;

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
        THROW 51217, 'Target item still has source or journal references after cleanup.', 1;

COMMIT;

PRINT 'After cleanup - items';
SELECT ItemId, ItemCode, ItemName, ItemType, SetPacking, BaseUnitId, Inactive, IsDeleted
FROM dbo.Item
WHERE ItemId IN (@TargetItemId, @ReplacementItemId)
ORDER BY ItemId;

PRINT 'After cleanup - replacement units';
SELECT ItemUnitId, ItemId, Unit, FactorToBase, MultipleToBase, IsBaseUnit, IsDefaultSalesUnit, Inactive
FROM dbo.ItemUnit
WHERE ItemId IN (@TargetItemId, @ReplacementItemId)
ORDER BY ItemId, ItemUnitId;

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
UNION ALL SELECT 'TempSales', COUNT(*) FROM dbo.TempSales WHERE ItemId = @TargetItemId
UNION ALL SELECT 'ItemUnit', COUNT(*) FROM dbo.ItemUnit WHERE ItemId = @TargetItemId;
