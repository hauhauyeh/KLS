SET NOCOUNT ON;

DECLARE @LocalOnlyStart int = 100000;

SELECT
    'SourceTarget' AS CheckName,
    'GUS_2026' AS SourceDatabaseName,
    'ASAG_2026' AS TargetDatabaseName,
    @LocalOnlyStart AS LocalOnlyStartId;

SELECT
    CheckName,
    CountValue
FROM (
    SELECT 'SourceItemCount' AS CheckName, COUNT(*) AS CountValue
    FROM GUS_2026.dbo.Item

    UNION ALL
    SELECT 'TargetItemCount', COUNT(*)
    FROM ASAG_2026.dbo.Item

    UNION ALL
    SELECT 'SourceItemUnitCount', COUNT(*)
    FROM GUS_2026.dbo.ItemUnit

    UNION ALL
    SELECT 'TargetItemUnitCount', COUNT(*)
    FROM ASAG_2026.dbo.ItemUnit

    UNION ALL
    SELECT 'MissingTargetItemCount', COUNT(*)
    FROM GUS_2026.dbo.Item s
    LEFT JOIN ASAG_2026.dbo.Item t ON t.ItemId = s.ItemId
    WHERE t.ItemId IS NULL

    UNION ALL
    SELECT 'MissingTargetItemUnitCount', COUNT(*)
    FROM GUS_2026.dbo.ItemUnit s
    LEFT JOIN ASAG_2026.dbo.ItemUnit t ON t.ItemUnitId = s.ItemUnitId
    WHERE t.ItemUnitId IS NULL

    UNION ALL
    SELECT 'TargetOnlyLowRangeItemCount', COUNT(*)
    FROM ASAG_2026.dbo.Item t
    LEFT JOIN GUS_2026.dbo.Item s ON s.ItemId = t.ItemId
    WHERE s.ItemId IS NULL
      AND t.ItemId < @LocalOnlyStart

    UNION ALL
    SELECT 'TargetOnlyLowRangeItemUnitCount', COUNT(*)
    FROM ASAG_2026.dbo.ItemUnit t
    LEFT JOIN GUS_2026.dbo.ItemUnit s ON s.ItemUnitId = t.ItemUnitId
    WHERE s.ItemUnitId IS NULL
      AND t.ItemUnitId < @LocalOnlyStart

    UNION ALL
    SELECT 'ItemIdentityConflictCount', COUNT(*)
    FROM GUS_2026.dbo.Item s
    INNER JOIN ASAG_2026.dbo.Item t ON t.ItemId = s.ItemId
    WHERE ISNULL(s.ItemCode, '') <> ISNULL(t.ItemCode, '')
       OR ISNULL(s.ItemName, '') <> ISNULL(t.ItemName, '')
       OR ISNULL(s.ItemType, -1) <> ISNULL(t.ItemType, -1)
       OR ISNULL(s.BaseUnitId, -1) <> ISNULL(t.BaseUnitId, -1)
       OR ISNULL(s.CategoryId, -1) <> ISNULL(t.CategoryId, -1)
       OR ISNULL(s.StorageId, -1) <> ISNULL(t.StorageId, -1)

    UNION ALL
    SELECT 'ItemUnitImmutableConflictCount', COUNT(*)
    FROM GUS_2026.dbo.ItemUnit s
    INNER JOIN ASAG_2026.dbo.ItemUnit t ON t.ItemUnitId = s.ItemUnitId
    WHERE ISNULL(s.ItemId, -1) <> ISNULL(t.ItemId, -1)
       OR ISNULL(s.Unit, '') <> ISNULL(t.Unit, '')
       OR ISNULL(s.FactorToBase, -1) <> ISNULL(t.FactorToBase, -1)
       OR ISNULL(s.MultipleToBase, -1) <> ISNULL(t.MultipleToBase, -1)
       OR ISNULL(s.IsBaseUnit, 0) <> ISNULL(t.IsBaseUnit, 0)

    UNION ALL
    SELECT 'CategoryDependencyIssueCount', COUNT(*)
    FROM (
        SELECT DISTINCT CategoryId
        FROM GUS_2026.dbo.Item
        WHERE CategoryId IS NOT NULL
    ) x
    LEFT JOIN GUS_2026.dbo.ItemCategory s ON s.CategoryId = x.CategoryId
    LEFT JOIN ASAG_2026.dbo.ItemCategory t ON t.CategoryId = x.CategoryId
    WHERE t.CategoryId IS NULL
       OR ISNULL(s.CategoryName, '') <> ISNULL(t.CategoryName, '')

    UNION ALL
    SELECT 'StorageDependencyIssueCount', COUNT(*)
    FROM (
        SELECT DISTINCT StorageId
        FROM GUS_2026.dbo.Item
        WHERE StorageId IS NOT NULL
    ) x
    LEFT JOIN GUS_2026.dbo.ItemStorage s ON s.StorageId = x.StorageId
    LEFT JOIN ASAG_2026.dbo.ItemStorage t ON t.StorageId = x.StorageId
    WHERE t.StorageId IS NULL
       OR ISNULL(s.DisplayName, '') <> ISNULL(t.DisplayName, '')

    UNION ALL
    SELECT 'BaseUnitReferenceIssueCount', COUNT(*)
    FROM (
        SELECT 'Source' AS DbRole, i.ItemId, i.BaseUnitId
        FROM GUS_2026.dbo.Item i
        LEFT JOIN GUS_2026.dbo.ItemUnit u ON u.ItemUnitId = i.BaseUnitId
            AND u.ItemId = i.ItemId
        WHERE i.BaseUnitId IS NOT NULL
          AND u.ItemUnitId IS NULL

        UNION ALL
        SELECT 'Target', i.ItemId, i.BaseUnitId
        FROM ASAG_2026.dbo.Item i
        LEFT JOIN ASAG_2026.dbo.ItemUnit u ON u.ItemUnitId = i.BaseUnitId
            AND u.ItemId = i.ItemId
        WHERE i.BaseUnitId IS NOT NULL
          AND u.ItemUnitId IS NULL
    ) x

    UNION ALL
    SELECT 'TargetLowRangeDocumentReferenceCount',
        (SELECT COUNT(*) FROM ASAG_2026.dbo.SalesDetail WHERE ISNULL(ItemId, 0) < @LocalOnlyStart OR ISNULL(ItemUnitId, 0) < @LocalOnlyStart)
      + (SELECT COUNT(*) FROM ASAG_2026.dbo.TempSales WHERE ISNULL(ItemId, 0) < @LocalOnlyStart OR ISNULL(ItemUnitId, 0) < @LocalOnlyStart)
      + (SELECT COUNT(*) FROM ASAG_2026.dbo.PurchaseDetail WHERE ISNULL(ItemId, 0) < @LocalOnlyStart OR ISNULL(ItemUnitId, 0) < @LocalOnlyStart)
      + (SELECT COUNT(*) FROM ASAG_2026.dbo.TempPurchase WHERE ISNULL(ItemId, 0) < @LocalOnlyStart OR ISNULL(ItemUnitId, 0) < @LocalOnlyStart)
      + (SELECT COUNT(*) FROM ASAG_2026.dbo.TransactionJournalDetail WHERE ISNULL(ItemId, 0) < @LocalOnlyStart)
) q
ORDER BY CheckName;

SELECT TOP (50)
    s.ItemId,
    s.ItemCode,
    s.ItemName,
    s.ItemType,
    s.BaseUnitId,
    s.CategoryId,
    s.StorageId
FROM GUS_2026.dbo.Item s
LEFT JOIN ASAG_2026.dbo.Item t ON t.ItemId = s.ItemId
WHERE t.ItemId IS NULL
ORDER BY s.ItemId;

SELECT TOP (50)
    t.ItemId,
    t.ItemCode,
    t.ItemName,
    t.ItemType,
    t.BaseUnitId,
    t.CategoryId,
    t.StorageId
FROM ASAG_2026.dbo.Item t
LEFT JOIN GUS_2026.dbo.Item s ON s.ItemId = t.ItemId
WHERE s.ItemId IS NULL
  AND t.ItemId < @LocalOnlyStart
ORDER BY t.ItemId;

SELECT TOP (50)
    s.ItemId,
    s.ItemCode AS SourceItemCode,
    t.ItemCode AS TargetItemCode,
    s.ItemName AS SourceItemName,
    t.ItemName AS TargetItemName,
    s.ItemType AS SourceItemType,
    t.ItemType AS TargetItemType,
    s.BaseUnitId AS SourceBaseUnitId,
    t.BaseUnitId AS TargetBaseUnitId,
    s.CategoryId AS SourceCategoryId,
    t.CategoryId AS TargetCategoryId,
    s.StorageId AS SourceStorageId,
    t.StorageId AS TargetStorageId
FROM GUS_2026.dbo.Item s
INNER JOIN ASAG_2026.dbo.Item t ON t.ItemId = s.ItemId
WHERE ISNULL(s.ItemCode, '') <> ISNULL(t.ItemCode, '')
   OR ISNULL(s.ItemName, '') <> ISNULL(t.ItemName, '')
   OR ISNULL(s.ItemType, -1) <> ISNULL(t.ItemType, -1)
   OR ISNULL(s.BaseUnitId, -1) <> ISNULL(t.BaseUnitId, -1)
   OR ISNULL(s.CategoryId, -1) <> ISNULL(t.CategoryId, -1)
   OR ISNULL(s.StorageId, -1) <> ISNULL(t.StorageId, -1)
ORDER BY s.ItemId;

SELECT TOP (50)
    x.DbRole,
    x.ItemId,
    x.BaseUnitId
FROM (
    SELECT 'Source' AS DbRole, i.ItemId, i.BaseUnitId
    FROM GUS_2026.dbo.Item i
    LEFT JOIN GUS_2026.dbo.ItemUnit u ON u.ItemUnitId = i.BaseUnitId
        AND u.ItemId = i.ItemId
    WHERE i.BaseUnitId IS NOT NULL
      AND u.ItemUnitId IS NULL

    UNION ALL
    SELECT 'Target', i.ItemId, i.BaseUnitId
    FROM ASAG_2026.dbo.Item i
    LEFT JOIN ASAG_2026.dbo.ItemUnit u ON u.ItemUnitId = i.BaseUnitId
        AND u.ItemId = i.ItemId
    WHERE i.BaseUnitId IS NOT NULL
      AND u.ItemUnitId IS NULL
) x
ORDER BY x.DbRole, x.ItemId;

SELECT TOP (50)
    x.CategoryId,
    s.CategoryName AS SourceCategoryName,
    t.CategoryName AS TargetCategoryName
FROM (
    SELECT DISTINCT CategoryId
    FROM GUS_2026.dbo.Item
    WHERE CategoryId IS NOT NULL
) x
LEFT JOIN GUS_2026.dbo.ItemCategory s ON s.CategoryId = x.CategoryId
LEFT JOIN ASAG_2026.dbo.ItemCategory t ON t.CategoryId = x.CategoryId
WHERE t.CategoryId IS NULL
   OR ISNULL(s.CategoryName, '') <> ISNULL(t.CategoryName, '')
ORDER BY x.CategoryId;

SELECT TOP (50)
    x.StorageId,
    s.DisplayName AS SourceDisplayName,
    t.DisplayName AS TargetDisplayName
FROM (
    SELECT DISTINCT StorageId
    FROM GUS_2026.dbo.Item
    WHERE StorageId IS NOT NULL
) x
LEFT JOIN GUS_2026.dbo.ItemStorage s ON s.StorageId = x.StorageId
LEFT JOIN ASAG_2026.dbo.ItemStorage t ON t.StorageId = x.StorageId
WHERE t.StorageId IS NULL
   OR ISNULL(s.DisplayName, '') <> ISNULL(t.DisplayName, '')
ORDER BY x.StorageId;

SELECT TOP (50)
    s.ItemUnitId,
    s.ItemId,
    s.Unit,
    s.FactorToBase,
    s.MultipleToBase,
    s.IsBaseUnit,
    s.IsDefaultSalesUnit,
    s.Barcode
FROM GUS_2026.dbo.ItemUnit s
LEFT JOIN ASAG_2026.dbo.ItemUnit t ON t.ItemUnitId = s.ItemUnitId
WHERE t.ItemUnitId IS NULL
ORDER BY s.ItemUnitId;

SELECT TOP (50)
    t.ItemUnitId,
    t.ItemId,
    t.Unit,
    t.FactorToBase,
    t.MultipleToBase,
    t.IsBaseUnit,
    t.IsDefaultSalesUnit,
    t.Barcode
FROM ASAG_2026.dbo.ItemUnit t
LEFT JOIN GUS_2026.dbo.ItemUnit s ON s.ItemUnitId = t.ItemUnitId
WHERE s.ItemUnitId IS NULL
  AND t.ItemUnitId < @LocalOnlyStart
ORDER BY t.ItemUnitId;

SELECT TOP (50)
    s.ItemUnitId,
    s.ItemId AS SourceItemId,
    t.ItemId AS TargetItemId,
    s.Unit AS SourceUnit,
    t.Unit AS TargetUnit,
    s.FactorToBase AS SourceFactorToBase,
    t.FactorToBase AS TargetFactorToBase,
    s.MultipleToBase AS SourceMultipleToBase,
    t.MultipleToBase AS TargetMultipleToBase,
    s.IsBaseUnit AS SourceIsBaseUnit,
    t.IsBaseUnit AS TargetIsBaseUnit
FROM GUS_2026.dbo.ItemUnit s
INNER JOIN ASAG_2026.dbo.ItemUnit t ON t.ItemUnitId = s.ItemUnitId
WHERE ISNULL(s.ItemId, -1) <> ISNULL(t.ItemId, -1)
   OR ISNULL(s.Unit, '') <> ISNULL(t.Unit, '')
   OR ISNULL(s.FactorToBase, -1) <> ISNULL(t.FactorToBase, -1)
   OR ISNULL(s.MultipleToBase, -1) <> ISNULL(t.MultipleToBase, -1)
   OR ISNULL(s.IsBaseUnit, 0) <> ISNULL(t.IsBaseUnit, 0)
ORDER BY s.ItemUnitId;

SELECT
    DbRole,
    CheckName,
    ItemId,
    CountValue
FROM (
    SELECT 'Source' AS DbRole, 'BaseUnitCountNotOne' AS CheckName, ItemId, COUNT(*) AS CountValue
    FROM GUS_2026.dbo.ItemUnit
    WHERE ISNULL(Inactive, 0) = 0
      AND IsBaseUnit = 1
    GROUP BY ItemId
    HAVING COUNT(*) <> 1

    UNION ALL
    SELECT 'Target', 'BaseUnitCountNotOne', ItemId, COUNT(*)
    FROM ASAG_2026.dbo.ItemUnit
    WHERE ISNULL(Inactive, 0) = 0
      AND IsBaseUnit = 1
    GROUP BY ItemId
    HAVING COUNT(*) <> 1

    UNION ALL
    SELECT 'Source', 'DefaultSalesUnitCountOverOne', ItemId, COUNT(*)
    FROM GUS_2026.dbo.ItemUnit
    WHERE ISNULL(Inactive, 0) = 0
      AND IsDefaultSalesUnit = 1
    GROUP BY ItemId
    HAVING COUNT(*) > 1

    UNION ALL
    SELECT 'Target', 'DefaultSalesUnitCountOverOne', ItemId, COUNT(*)
    FROM ASAG_2026.dbo.ItemUnit
    WHERE ISNULL(Inactive, 0) = 0
      AND IsDefaultSalesUnit = 1
    GROUP BY ItemId
    HAVING COUNT(*) > 1
) q
ORDER BY DbRole, CheckName, ItemId;

SELECT
    'GUS_2026.dbo.Item' AS ObjectName,
    IDENT_CURRENT('GUS_2026.dbo.Item') AS CurrentIdentity,
    (SELECT COUNT(*) FROM GUS_2026.dbo.Item WHERE ItemId >= @LocalOnlyStart) AS HighRangeRowCount
UNION ALL
SELECT
    'GUS_2026.dbo.ItemUnit',
    IDENT_CURRENT('GUS_2026.dbo.ItemUnit'),
    (SELECT COUNT(*) FROM GUS_2026.dbo.ItemUnit WHERE ItemUnitId >= @LocalOnlyStart)
UNION ALL
SELECT
    'ASAG_2026.dbo.Item',
    IDENT_CURRENT('ASAG_2026.dbo.Item'),
    (SELECT COUNT(*) FROM ASAG_2026.dbo.Item WHERE ItemId >= @LocalOnlyStart)
UNION ALL
SELECT
    'ASAG_2026.dbo.ItemUnit',
    IDENT_CURRENT('ASAG_2026.dbo.ItemUnit'),
    (SELECT COUNT(*) FROM ASAG_2026.dbo.ItemUnit WHERE ItemUnitId >= @LocalOnlyStart);

SELECT
    'SalesDetail' AS TableName,
    COUNT(*) AS LowRangeReferenceCount
FROM ASAG_2026.dbo.SalesDetail
WHERE ISNULL(ItemId, 0) < @LocalOnlyStart
   OR ISNULL(ItemUnitId, 0) < @LocalOnlyStart

UNION ALL
SELECT 'TempSales', COUNT(*)
FROM ASAG_2026.dbo.TempSales
WHERE ISNULL(ItemId, 0) < @LocalOnlyStart
   OR ISNULL(ItemUnitId, 0) < @LocalOnlyStart

UNION ALL
SELECT 'PurchaseDetail', COUNT(*)
FROM ASAG_2026.dbo.PurchaseDetail
WHERE ISNULL(ItemId, 0) < @LocalOnlyStart
   OR ISNULL(ItemUnitId, 0) < @LocalOnlyStart

UNION ALL
SELECT 'TempPurchase', COUNT(*)
FROM ASAG_2026.dbo.TempPurchase
WHERE ISNULL(ItemId, 0) < @LocalOnlyStart
   OR ISNULL(ItemUnitId, 0) < @LocalOnlyStart

UNION ALL
SELECT 'TransactionJournalDetail', COUNT(*)
FROM ASAG_2026.dbo.TransactionJournalDetail
WHERE ISNULL(ItemId, 0) < @LocalOnlyStart
ORDER BY TableName;
