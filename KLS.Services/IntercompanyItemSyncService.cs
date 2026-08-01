using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models.Intercompany;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;

namespace KLS.Services
{
    public class IntercompanyItemSyncService : BaseService, IIntercompanyItemSyncService
    {
        private const int LocalOnlyStartId = 100000;
        private const int MaxBlockerRows = 50;
        private const string LegacyTargetCode = "ASA";
        private const string LegacyTargetConnectionStringName = "IntercompanyTarget";

        private readonly IConfiguration _configuration;

        public IntercompanyItemSyncService(IUnitOfWork uow, IConfiguration configuration) : base(uow)
        {
            _configuration = configuration;
        }

        public List<IntercompanyItemSyncTargetDto> Targets()
        {
            return GetConfiguredTargetCodes()
                .Select(targetCode =>
                {
                    var connectionString = GetTargetConnectionString(targetCode);
                    if (string.IsNullOrWhiteSpace(connectionString))
                        throw new ArgumentException($"ConnectionStrings:{targetCode} is required for intercompany item sync target {targetCode}.");

                    return new IntercompanyItemSyncTargetDto
                    {
                        TargetCode = targetCode,
                        DisplayName = targetCode
                    };
                })
                .ToList();
        }

        public IntercompanyItemSyncPreviewDto Preview(string targetCode)
        {
            var sourceConnectionString = _configuration.GetConnectionString("Default");
            var target = ResolveTarget(targetCode);

            if (string.IsNullOrWhiteSpace(sourceConnectionString))
                throw new ArgumentException("ConnectionStrings:Default is required.");

            using var sourceConnection = new SqlConnection(sourceConnectionString);
            using var targetConnection = new SqlConnection(target.ConnectionString);
            sourceConnection.Open();
            targetConnection.Open();
            EnsureExpectedSyncDatabases(sourceConnection.Database, targetConnection.Database);

            var sourceItems = LoadItems(sourceConnection);
            var targetItems = LoadItems(targetConnection);
            var sourceUnits = LoadItemUnits(sourceConnection);
            var targetUnits = LoadItemUnits(targetConnection);
            var sourceCategories = LoadCategories(sourceConnection);
            var targetCategories = LoadCategories(targetConnection);
            var sourceStorages = LoadStorages(sourceConnection);
            var targetStorages = LoadStorages(targetConnection);

            var preview = new IntercompanyItemSyncPreviewDto
            {
                TargetCode = target.TargetCode,
                SourceDatabaseName = sourceConnection.Database,
                TargetDatabaseName = targetConnection.Database,
                LocalOnlyStartId = LocalOnlyStartId
            };

            AddCheck(preview, "SourceItemCount", sourceItems.Count, false);
            AddCheck(preview, "TargetItemCount", targetItems.Count, false);
            AddCheck(preview, "SourceItemUnitCount", sourceUnits.Count, false);
            AddCheck(preview, "TargetItemUnitCount", targetUnits.Count, false);

            var missingTargetItems = sourceItems.Values
                .Where(s => !targetItems.ContainsKey(s.ItemId))
                .ToList();
            AddCheck(preview, "MissingTargetItemCount", missingTargetItems.Count, false);
            AddSamples(preview, "MissingTargetItem", missingTargetItems, false, i => i.ItemId, null, i => i.ItemCode, null, "Target item is missing and would need sync insert.");

            var missingTargetUnits = sourceUnits.Values
                .Where(s => !targetUnits.ContainsKey(s.ItemUnitId))
                .ToList();
            AddCheck(preview, "MissingTargetItemUnitCount", missingTargetUnits.Count, false);
            AddSamples(preview, "MissingTargetItemUnit", missingTargetUnits, false, u => u.ItemId, u => u.ItemUnitId, u => u.Unit, null, "Target item unit is missing and would need sync insert.");

            var targetOnlyLowRangeItems = targetItems.Values
                .Where(t => t.ItemId < LocalOnlyStartId && !sourceItems.ContainsKey(t.ItemId))
                .ToList();
            AddCheck(preview, "TargetOnlyLowRangeItemCount", targetOnlyLowRangeItems.Count, true);
            AddSamples(preview, "TargetOnlyLowRangeItem", targetOnlyLowRangeItems, true, i => i.ItemId, null, null, i => i.ItemCode, "Target has a local-only item inside the synced ID range.");

            var targetOnlyLowRangeUnits = targetUnits.Values
                .Where(t => t.ItemUnitId < LocalOnlyStartId && !sourceUnits.ContainsKey(t.ItemUnitId))
                .ToList();
            AddCheck(preview, "TargetOnlyLowRangeItemUnitCount", targetOnlyLowRangeUnits.Count, true);
            AddSamples(preview, "TargetOnlyLowRangeItemUnit", targetOnlyLowRangeUnits, true, u => u.ItemId, u => u.ItemUnitId, null, u => u.Unit, "Target has a local-only item unit inside the synced ID range.");

            var itemConflicts = sourceItems.Values
                .Where(s => targetItems.TryGetValue(s.ItemId, out var t) && IsItemIdentityConflict(s, t))
                .ToList();
            AddCheck(preview, "ItemIdentityConflictCount", itemConflicts.Count, true);
            AddItemConflictSamples(preview, itemConflicts, targetItems);

            var unitConflicts = sourceUnits.Values
                .Where(s => targetUnits.TryGetValue(s.ItemUnitId, out var t) && IsItemUnitImmutableConflict(s, t))
                .ToList();
            AddCheck(preview, "ItemUnitImmutableConflictCount", unitConflicts.Count, true);
            AddItemUnitConflictSamples(preview, unitConflicts, targetUnits);

            var categoryIssues = sourceItems.Values
                .Where(i => i.CategoryId.HasValue)
                .Select(i => i.CategoryId!.Value)
                .Distinct()
                .Where(id => !targetCategories.TryGetValue(id, out var targetName)
                    || !TextEquals(sourceCategories.GetValueOrDefault(id), targetName))
                .ToList();
            AddCheck(preview, "CategoryDependencyIssueCount", categoryIssues.Count, true);
            AddDependencySamples(preview, "CategoryDependencyIssue", categoryIssues, sourceCategories, targetCategories);

            var storageIssues = sourceItems.Values
                .Where(i => i.StorageId.HasValue)
                .Select(i => i.StorageId!.Value)
                .Distinct()
                .Where(id => !targetStorages.TryGetValue(id, out var targetName)
                    || !TextEquals(sourceStorages.GetValueOrDefault(id), targetName))
                .ToList();
            AddCheck(preview, "StorageDependencyIssueCount", storageIssues.Count, true);
            AddDependencySamples(preview, "StorageDependencyIssue", storageIssues, sourceStorages, targetStorages);

            var baseUnitIssues = GetBaseUnitIssues("Source", sourceItems, sourceUnits)
                .Concat(GetBaseUnitIssues("Target", targetItems, targetUnits))
                .ToList();
            AddCheck(preview, "BaseUnitReferenceIssueCount", baseUnitIssues.Count, true);
            AddBaseUnitIssueSamples(preview, baseUnitIssues);

            var itemCodeCollisions = sourceItems.Values
                .Where(s => !string.IsNullOrWhiteSpace(s.ItemCode)
                    && targetItems.Values.Any(t => t.ItemId != s.ItemId && TextEquals(t.ItemCode, s.ItemCode)))
                .ToList();
            AddCheck(preview, "ItemCodeCollisionCount", itemCodeCollisions.Count, true);
            AddSamples(preview, "ItemCodeCollision", itemCodeCollisions, true, i => i.ItemId, null, i => i.ItemCode, i => i.ItemCode, "Target has the same item code on a different item.");

            var baseUnitCountIssues = GetBaseUnitCountIssues("Source", sourceItems, sourceUnits)
                .Concat(GetBaseUnitCountIssues("Target", targetItems, targetUnits))
                .ToList();
            AddCheck(preview, "BaseUnitCountIssueCount", baseUnitCountIssues.Count, true);
            AddCountIssueSamples(preview, "BaseUnitCountIssue", baseUnitCountIssues);

            var defaultSalesUnitCountIssues = GetDefaultSalesUnitCountIssues("Source", sourceUnits)
                .Concat(GetDefaultSalesUnitCountIssues("Target", targetUnits))
                .ToList();
            AddCheck(preview, "DefaultSalesUnitCountIssueCount", defaultSalesUnitCountIssues.Count, true);
            AddCountIssueSamples(preview, "DefaultSalesUnitCountIssue", defaultSalesUnitCountIssues);

            var targetLowRangeDocumentReferenceCount = GetTargetLowRangeDocumentReferenceCount(targetConnection);
            AddCheck(preview, "TargetLowRangeDocumentReferenceCount", targetLowRangeDocumentReferenceCount, false);

            return preview;
        }

        public IntercompanyItemSyncRunDto Sync(string targetCode)
        {
            var preview = Preview(targetCode);
            if (preview.HasBlockers)
                throw new ArgumentException("Intercompany item sync has blockers. Run preview and resolve blockers before sync.");

            var sourceConnectionString = _configuration.GetConnectionString("Default");
            var target = ResolveTarget(targetCode);

            if (string.IsNullOrWhiteSpace(sourceConnectionString))
                throw new ArgumentException("ConnectionStrings:Default is required.");

            using var sourceConnection = new SqlConnection(sourceConnectionString);
            using var targetConnection = new SqlConnection(target.ConnectionString);
            sourceConnection.Open();
            targetConnection.Open();
            EnsureExpectedSyncDatabases(sourceConnection.Database, targetConnection.Database);

            var sourceItems = LoadItems(sourceConnection);
            var targetItems = LoadItems(targetConnection);
            var sourceUnits = LoadItemUnits(sourceConnection);
            var targetUnits = LoadItemUnits(targetConnection);

            using var transaction = targetConnection.BeginTransaction();
            var itemIdentityInsertOn = false;
            var itemUnitIdentityInsertOn = false;

            try
            {
                ExecuteNonQuery(targetConnection, transaction, "SET XACT_ABORT ON");

                var result = new IntercompanyItemSyncRunDto
                {
                    TargetCode = target.TargetCode,
                    SourceDatabaseName = sourceConnection.Database,
                    TargetDatabaseName = targetConnection.Database
                };

                var missingItems = sourceItems.Values
                    .Where(s => !targetItems.ContainsKey(s.ItemId))
                    .OrderBy(s => s.ItemId)
                    .ToList();

                if (missingItems.Count > 0)
                {
                    ExecuteNonQuery(targetConnection, transaction, "SET IDENTITY_INSERT dbo.Item ON");
                    itemIdentityInsertOn = true;

                    foreach (var item in missingItems)
                    {
                        result.InsertedItemCount += InsertItem(targetConnection, transaction, item);
                    }

                    ExecuteNonQuery(targetConnection, transaction, "SET IDENTITY_INSERT dbo.Item OFF");
                    itemIdentityInsertOn = false;
                }

                foreach (var item in sourceItems.Values.Where(s => targetItems.ContainsKey(s.ItemId)).OrderBy(s => s.ItemId))
                {
                    result.UpdatedItemCount += UpdateItem(targetConnection, transaction, item);
                }

                var matchedUnits = sourceUnits.Values
                    .Where(s => targetUnits.ContainsKey(s.ItemUnitId))
                    .OrderBy(s => s.ItemUnitId)
                    .ToList();

                foreach (var unit in matchedUnits.Where(u => !u.IsDefaultSalesUnit))
                {
                    result.UpdatedItemUnitCount += UpdateItemUnit(targetConnection, transaction, unit);
                }

                var missingUnits = sourceUnits.Values
                    .Where(s => !targetUnits.ContainsKey(s.ItemUnitId))
                    .OrderBy(s => s.ItemUnitId)
                    .ToList();

                if (missingUnits.Count > 0)
                {
                    ExecuteNonQuery(targetConnection, transaction, "SET IDENTITY_INSERT dbo.ItemUnit ON");
                    itemUnitIdentityInsertOn = true;

                    foreach (var unit in missingUnits)
                    {
                        result.InsertedItemUnitCount += InsertItemUnit(targetConnection, transaction, unit);
                    }

                    ExecuteNonQuery(targetConnection, transaction, "SET IDENTITY_INSERT dbo.ItemUnit OFF");
                    itemUnitIdentityInsertOn = false;
                }

                foreach (var unit in matchedUnits.Where(u => u.IsDefaultSalesUnit))
                {
                    result.UpdatedItemUnitCount += UpdateItemUnit(targetConnection, transaction, unit);
                }

                foreach (var item in sourceItems.Values.OrderBy(s => s.ItemId))
                {
                    result.UpdatedBaseUnitCount += UpdateItemBaseUnit(targetConnection, transaction, item);
                }

                transaction.Commit();
                return result;
            }
            catch
            {
                if (itemIdentityInsertOn)
                    TryExecuteNonQuery(targetConnection, transaction, "SET IDENTITY_INSERT dbo.Item OFF");

                if (itemUnitIdentityInsertOn)
                    TryExecuteNonQuery(targetConnection, transaction, "SET IDENTITY_INSERT dbo.ItemUnit OFF");

                TryRollback(transaction);
                throw;
            }
        }

        private static Dictionary<int, ItemSnapshot> LoadItems(SqlConnection connection)
        {
            const string sql = @"
SELECT
    ItemId,
    ItemType,
    ItemCode,
    ItemName,
    ItemName2,
    ItemSearchTag,
    ItemLongDesc,
    ItemBoxDesc,
    ItemBrand,
    SetPacking,
    PackSize,
    BaseUnitId,
    CategoryId,
    StorageId,
    PaletteFactor,
    SaftyInventory,
    ActualSaftyInventory,
    RefillInventory,
    IsWeightItem,
    IsMetricWeight,
    IsMetricDimension,
    IsVolumeManual,
    CaseWeight,
    CaseLength,
    CaseWidth,
    CaseHeight,
    CaseVolumeInCubicFeet,
    CaseVolumeInCubicMeter,
    Inactive,
    IsDeleted,
    IsTaxable,
    IsHRTaxable,
    IsHighlighted,
    IsImport
FROM dbo.Item";

            using var command = new SqlCommand(sql, connection);
            using var reader = command.ExecuteReader();
            var rows = new Dictionary<int, ItemSnapshot>();

            while (reader.Read())
            {
                var row = new ItemSnapshot(
                    GetInt32(reader, "ItemId"),
                    GetNullableString(reader, "ItemType"),
                    GetString(reader, "ItemCode"),
                    GetNullableString(reader, "ItemName"),
                    GetNullableString(reader, "ItemName2"),
                    GetNullableString(reader, "ItemSearchTag"),
                    GetNullableString(reader, "ItemLongDesc"),
                    GetNullableString(reader, "ItemBoxDesc"),
                    GetNullableString(reader, "ItemBrand"),
                    GetNullableString(reader, "SetPacking"),
                    GetNullableString(reader, "PackSize"),
                    GetNullableInt32(reader, "BaseUnitId"),
                    GetNullableInt32(reader, "CategoryId"),
                    GetNullableInt32(reader, "StorageId"),
                    GetNullableDecimal(reader, "PaletteFactor"),
                    GetNullableDecimal(reader, "SaftyInventory"),
                    GetNullableDecimal(reader, "ActualSaftyInventory"),
                    GetNullableDecimal(reader, "RefillInventory"),
                    GetBoolean(reader, "IsWeightItem"),
                    GetBoolean(reader, "IsMetricWeight"),
                    GetBoolean(reader, "IsMetricDimension"),
                    GetBoolean(reader, "IsVolumeManual"),
                    GetNullableDecimal(reader, "CaseWeight"),
                    GetNullableDecimal(reader, "CaseLength"),
                    GetNullableDecimal(reader, "CaseWidth"),
                    GetNullableDecimal(reader, "CaseHeight"),
                    GetNullableDecimal(reader, "CaseVolumeInCubicFeet"),
                    GetNullableDecimal(reader, "CaseVolumeInCubicMeter"),
                    GetBoolean(reader, "Inactive"),
                    GetBoolean(reader, "IsDeleted"),
                    GetBoolean(reader, "IsTaxable"),
                    GetBoolean(reader, "IsHRTaxable"),
                    GetBoolean(reader, "IsHighlighted"),
                    GetBoolean(reader, "IsImport"));

                rows[row.ItemId] = row;
            }

            return rows;
        }

        private static Dictionary<int, ItemUnitSnapshot> LoadItemUnits(SqlConnection connection)
        {
            const string sql = @"
SELECT ItemUnitId, ItemId, Unit, FactorToBase, PricePercentToBase, MultipleToBase, IsBaseUnit, IsDefaultSalesUnit, Barcode, Inactive
FROM dbo.ItemUnit";

            using var command = new SqlCommand(sql, connection);
            using var reader = command.ExecuteReader();
            var rows = new Dictionary<int, ItemUnitSnapshot>();

            while (reader.Read())
            {
                var row = new ItemUnitSnapshot(
                    GetInt32(reader, "ItemUnitId"),
                    GetInt32(reader, "ItemId"),
                    GetString(reader, "Unit"),
                    GetDecimal(reader, "FactorToBase"),
                    GetNullableDecimal(reader, "PricePercentToBase"),
                    GetInt32(reader, "MultipleToBase"),
                    GetBoolean(reader, "IsBaseUnit"),
                    GetBoolean(reader, "IsDefaultSalesUnit"),
                    GetNullableString(reader, "Barcode"),
                    GetBoolean(reader, "Inactive"));

                rows[row.ItemUnitId] = row;
            }

            return rows;
        }

        private static Dictionary<int, string?> LoadCategories(SqlConnection connection)
        {
            const string sql = @"
SELECT CategoryId, CategoryName
FROM dbo.ItemCategory";

            return LoadLookup(connection, sql, "CategoryId", "CategoryName");
        }

        private static Dictionary<int, string?> LoadStorages(SqlConnection connection)
        {
            const string sql = @"
SELECT StorageId, DisplayName
FROM dbo.ItemStorage";

            return LoadLookup(connection, sql, "StorageId", "DisplayName");
        }

        private static Dictionary<int, string?> LoadLookup(SqlConnection connection, string sql, string idColumn, string nameColumn)
        {
            using var command = new SqlCommand(sql, connection);
            using var reader = command.ExecuteReader();
            var rows = new Dictionary<int, string?>();

            while (reader.Read())
            {
                rows[GetInt32(reader, idColumn)] = GetNullableString(reader, nameColumn);
            }

            return rows;
        }

        private static int GetTargetLowRangeDocumentReferenceCount(SqlConnection connection)
        {
            const string sql = @"
SELECT
    (SELECT COUNT(*) FROM dbo.SalesDetail WHERE ISNULL(ItemId, 0) < @LocalOnlyStartId OR ISNULL(ItemUnitId, 0) < @LocalOnlyStartId)
  + (SELECT COUNT(*) FROM dbo.TempSales WHERE ISNULL(ItemId, 0) < @LocalOnlyStartId OR ISNULL(ItemUnitId, 0) < @LocalOnlyStartId)
  + (SELECT COUNT(*) FROM dbo.PurchaseDetail WHERE ISNULL(ItemId, 0) < @LocalOnlyStartId OR ISNULL(ItemUnitId, 0) < @LocalOnlyStartId)
  + (SELECT COUNT(*) FROM dbo.TempPurchase WHERE ISNULL(ItemId, 0) < @LocalOnlyStartId OR ISNULL(ItemUnitId, 0) < @LocalOnlyStartId)
  + (SELECT COUNT(*) FROM dbo.TransactionJournalDetail WHERE ISNULL(ItemId, 0) < @LocalOnlyStartId)";

            using var command = new SqlCommand(sql, connection);
            command.Parameters.Add("@LocalOnlyStartId", SqlDbType.Int).Value = LocalOnlyStartId;
            return Convert.ToInt32(command.ExecuteScalar());
        }

        private static int InsertItem(SqlConnection connection, SqlTransaction transaction, ItemSnapshot item)
        {
            const string sql = @"
INSERT INTO dbo.Item (
    ItemId, ItemType, ItemCode, ItemName, ItemName2, ItemSearchTag, ItemLongDesc, ItemBoxDesc, ItemBrand,
    SetPacking, PackSize, BaseUnitId, CategoryId, StorageId, PaletteFactor, SaftyInventory, ActualSaftyInventory,
    RefillInventory, IsWeightItem, IsMetricWeight, IsMetricDimension, IsVolumeManual, CaseWeight, CaseLength,
    CaseWidth, CaseHeight, CaseVolumeInCubicFeet, CaseVolumeInCubicMeter, Inactive, IsDeleted, IsTaxable,
    IsHRTaxable, IsHighlighted, IsImport
) VALUES (
    @ItemId, @ItemType, @ItemCode, @ItemName, @ItemName2, @ItemSearchTag, @ItemLongDesc, @ItemBoxDesc, @ItemBrand,
    @SetPacking, @PackSize, NULL, @CategoryId, @StorageId, @PaletteFactor, @SaftyInventory, @ActualSaftyInventory,
    @RefillInventory, @IsWeightItem, @IsMetricWeight, @IsMetricDimension, @IsVolumeManual, @CaseWeight, @CaseLength,
    @CaseWidth, @CaseHeight, @CaseVolumeInCubicFeet, @CaseVolumeInCubicMeter, @Inactive, @IsDeleted, @IsTaxable,
    @IsHRTaxable, @IsHighlighted, @IsImport
)";

            using var command = CreateItemCommand(connection, transaction, sql, item);
            return command.ExecuteNonQuery();
        }

        private static int UpdateItem(SqlConnection connection, SqlTransaction transaction, ItemSnapshot item)
        {
            const string sql = @"
UPDATE dbo.Item
SET
    ItemType = @ItemType,
    ItemCode = @ItemCode,
    ItemName = @ItemName,
    ItemName2 = @ItemName2,
    ItemSearchTag = @ItemSearchTag,
    ItemLongDesc = @ItemLongDesc,
    ItemBoxDesc = @ItemBoxDesc,
    ItemBrand = @ItemBrand,
    SetPacking = @SetPacking,
    PackSize = @PackSize,
    CategoryId = @CategoryId,
    StorageId = @StorageId,
    PaletteFactor = @PaletteFactor,
    SaftyInventory = @SaftyInventory,
    ActualSaftyInventory = @ActualSaftyInventory,
    RefillInventory = @RefillInventory,
    IsWeightItem = @IsWeightItem,
    IsMetricWeight = @IsMetricWeight,
    IsMetricDimension = @IsMetricDimension,
    IsVolumeManual = @IsVolumeManual,
    CaseWeight = @CaseWeight,
    CaseLength = @CaseLength,
    CaseWidth = @CaseWidth,
    CaseHeight = @CaseHeight,
    CaseVolumeInCubicFeet = @CaseVolumeInCubicFeet,
    CaseVolumeInCubicMeter = @CaseVolumeInCubicMeter,
    Inactive = @Inactive,
    IsDeleted = @IsDeleted,
    IsTaxable = @IsTaxable,
    IsHRTaxable = @IsHRTaxable,
    IsHighlighted = @IsHighlighted,
    IsImport = @IsImport,
    UpdatedAt = GETUTCDATE()
WHERE ItemId = @ItemId
  AND (
      ISNULL(ItemType, '') <> ISNULL(@ItemType, '')
      OR ItemCode <> @ItemCode
      OR ISNULL(ItemName, '') <> ISNULL(@ItemName, '')
      OR ISNULL(ItemName2, '') <> ISNULL(@ItemName2, '')
      OR ISNULL(ItemSearchTag, '') <> ISNULL(@ItemSearchTag, '')
      OR ISNULL(ItemLongDesc, '') <> ISNULL(@ItemLongDesc, '')
      OR ISNULL(ItemBoxDesc, '') <> ISNULL(@ItemBoxDesc, '')
      OR ISNULL(ItemBrand, '') <> ISNULL(@ItemBrand, '')
      OR ISNULL(SetPacking, '') <> ISNULL(@SetPacking, '')
      OR ISNULL(PackSize, '') <> ISNULL(@PackSize, '')
      OR ISNULL(CategoryId, -1) <> ISNULL(@CategoryId, -1)
      OR ISNULL(StorageId, -1) <> ISNULL(@StorageId, -1)
      OR ISNULL(PaletteFactor, -1) <> ISNULL(@PaletteFactor, -1)
      OR ISNULL(SaftyInventory, -1) <> ISNULL(@SaftyInventory, -1)
      OR ISNULL(ActualSaftyInventory, -1) <> ISNULL(@ActualSaftyInventory, -1)
      OR ISNULL(RefillInventory, -1) <> ISNULL(@RefillInventory, -1)
      OR IsWeightItem <> @IsWeightItem
      OR IsMetricWeight <> @IsMetricWeight
      OR IsMetricDimension <> @IsMetricDimension
      OR IsVolumeManual <> @IsVolumeManual
      OR ISNULL(CaseWeight, -1) <> ISNULL(@CaseWeight, -1)
      OR ISNULL(CaseLength, -1) <> ISNULL(@CaseLength, -1)
      OR ISNULL(CaseWidth, -1) <> ISNULL(@CaseWidth, -1)
      OR ISNULL(CaseHeight, -1) <> ISNULL(@CaseHeight, -1)
      OR ISNULL(CaseVolumeInCubicFeet, -1) <> ISNULL(@CaseVolumeInCubicFeet, -1)
      OR ISNULL(CaseVolumeInCubicMeter, -1) <> ISNULL(@CaseVolumeInCubicMeter, -1)
      OR Inactive <> @Inactive
      OR IsDeleted <> @IsDeleted
      OR IsTaxable <> @IsTaxable
      OR IsHRTaxable <> @IsHRTaxable
      OR IsHighlighted <> @IsHighlighted
      OR IsImport <> @IsImport
  )";

            using var command = CreateItemCommand(connection, transaction, sql, item);
            return command.ExecuteNonQuery();
        }

        private static int UpdateItemBaseUnit(SqlConnection connection, SqlTransaction transaction, ItemSnapshot item)
        {
            const string sql = @"
UPDATE i
SET i.BaseUnitId = @BaseUnitId,
    i.UpdatedAt = GETUTCDATE()
FROM dbo.Item i
WHERE i.ItemId = @ItemId
  AND ISNULL(i.BaseUnitId, -1) <> ISNULL(@BaseUnitId, -1)
  AND (
      @BaseUnitId IS NULL
      OR EXISTS (
          SELECT 1
          FROM dbo.ItemUnit u
          WHERE u.ItemUnitId = @BaseUnitId
            AND u.ItemId = @ItemId
      )
  )";

            using var command = new SqlCommand(sql, connection, transaction);
            AddParameter(command, "@ItemId", item.ItemId);
            AddParameter(command, "@BaseUnitId", item.BaseUnitId);
            return command.ExecuteNonQuery();
        }

        private static int InsertItemUnit(SqlConnection connection, SqlTransaction transaction, ItemUnitSnapshot unit)
        {
            const string sql = @"
INSERT INTO dbo.ItemUnit (
    ItemUnitId, ItemId, Unit, FactorToBase, PricePercentToBase, IsBaseUnit, IsDefaultSalesUnit, Barcode, Inactive, MultipleToBase
) VALUES (
    @ItemUnitId, @ItemId, @Unit, @FactorToBase, @PricePercentToBase, @IsBaseUnit, @IsDefaultSalesUnit, @Barcode, @Inactive, @MultipleToBase
)";

            using var command = CreateItemUnitCommand(connection, transaction, sql, unit);
            return command.ExecuteNonQuery();
        }

        private static int UpdateItemUnit(SqlConnection connection, SqlTransaction transaction, ItemUnitSnapshot unit)
        {
            const string sql = @"
UPDATE dbo.ItemUnit
SET
    Unit = @Unit,
    PricePercentToBase = @PricePercentToBase,
    IsDefaultSalesUnit = @IsDefaultSalesUnit,
    Barcode = @Barcode,
    Inactive = @Inactive
WHERE ItemUnitId = @ItemUnitId
  AND (
      Unit <> @Unit
      OR ISNULL(PricePercentToBase, -1) <> ISNULL(@PricePercentToBase, -1)
      OR IsDefaultSalesUnit <> @IsDefaultSalesUnit
      OR ISNULL(Barcode, '') <> ISNULL(@Barcode, '')
      OR Inactive <> @Inactive
  )";

            using var command = CreateItemUnitCommand(connection, transaction, sql, unit);
            return command.ExecuteNonQuery();
        }

        private static bool IsItemIdentityConflict(ItemSnapshot source, ItemSnapshot target)
        {
            return !TextEquals(source.ItemType, target.ItemType);
        }

        private static bool IsItemUnitImmutableConflict(ItemUnitSnapshot source, ItemUnitSnapshot target)
        {
            return source.ItemId != target.ItemId
                || source.FactorToBase != target.FactorToBase
                || source.MultipleToBase != target.MultipleToBase
                || source.IsBaseUnit != target.IsBaseUnit;
        }

        private static SqlCommand CreateItemCommand(SqlConnection connection, SqlTransaction transaction, string sql, ItemSnapshot item)
        {
            var command = new SqlCommand(sql, connection, transaction);
            AddParameter(command, "@ItemId", item.ItemId);
            AddParameter(command, "@ItemType", item.ItemType);
            AddParameter(command, "@ItemCode", item.ItemCode);
            AddParameter(command, "@ItemName", item.ItemName);
            AddParameter(command, "@ItemName2", item.ItemName2);
            AddParameter(command, "@ItemSearchTag", item.ItemSearchTag);
            AddParameter(command, "@ItemLongDesc", item.ItemLongDesc);
            AddParameter(command, "@ItemBoxDesc", item.ItemBoxDesc);
            AddParameter(command, "@ItemBrand", item.ItemBrand);
            AddParameter(command, "@SetPacking", item.SetPacking);
            AddParameter(command, "@PackSize", item.PackSize);
            AddParameter(command, "@CategoryId", item.CategoryId);
            AddParameter(command, "@StorageId", item.StorageId);
            AddParameter(command, "@PaletteFactor", item.PaletteFactor);
            AddParameter(command, "@SaftyInventory", item.SaftyInventory);
            AddParameter(command, "@ActualSaftyInventory", item.ActualSaftyInventory);
            AddParameter(command, "@RefillInventory", item.RefillInventory);
            AddParameter(command, "@IsWeightItem", item.IsWeightItem);
            AddParameter(command, "@IsMetricWeight", item.IsMetricWeight);
            AddParameter(command, "@IsMetricDimension", item.IsMetricDimension);
            AddParameter(command, "@IsVolumeManual", item.IsVolumeManual);
            AddParameter(command, "@CaseWeight", item.CaseWeight);
            AddParameter(command, "@CaseLength", item.CaseLength);
            AddParameter(command, "@CaseWidth", item.CaseWidth);
            AddParameter(command, "@CaseHeight", item.CaseHeight);
            AddParameter(command, "@CaseVolumeInCubicFeet", item.CaseVolumeInCubicFeet);
            AddParameter(command, "@CaseVolumeInCubicMeter", item.CaseVolumeInCubicMeter);
            AddParameter(command, "@Inactive", item.Inactive);
            AddParameter(command, "@IsDeleted", item.IsDeleted);
            AddParameter(command, "@IsTaxable", item.IsTaxable);
            AddParameter(command, "@IsHRTaxable", item.IsHRTaxable);
            AddParameter(command, "@IsHighlighted", item.IsHighlighted);
            AddParameter(command, "@IsImport", item.IsImport);
            return command;
        }

        private static SqlCommand CreateItemUnitCommand(SqlConnection connection, SqlTransaction transaction, string sql, ItemUnitSnapshot unit)
        {
            var command = new SqlCommand(sql, connection, transaction);
            AddParameter(command, "@ItemUnitId", unit.ItemUnitId);
            AddParameter(command, "@ItemId", unit.ItemId);
            AddParameter(command, "@Unit", unit.Unit);
            AddParameter(command, "@FactorToBase", unit.FactorToBase);
            AddParameter(command, "@PricePercentToBase", unit.PricePercentToBase);
            AddParameter(command, "@IsBaseUnit", unit.IsBaseUnit);
            AddParameter(command, "@IsDefaultSalesUnit", unit.IsDefaultSalesUnit);
            AddParameter(command, "@Barcode", unit.Barcode);
            AddParameter(command, "@Inactive", unit.Inactive);
            AddParameter(command, "@MultipleToBase", unit.MultipleToBase);
            return command;
        }

        private static int ExecuteNonQuery(SqlConnection connection, SqlTransaction transaction, string sql)
        {
            using var command = new SqlCommand(sql, connection, transaction);
            return command.ExecuteNonQuery();
        }

        private static void TryExecuteNonQuery(SqlConnection connection, SqlTransaction transaction, string sql)
        {
            try
            {
                ExecuteNonQuery(connection, transaction, sql);
            }
            catch
            {
                // Best-effort cleanup before rollback.
            }
        }

        private static void TryRollback(SqlTransaction transaction)
        {
            try
            {
                transaction.Rollback();
            }
            catch
            {
                // Preserve the original sync failure.
            }
        }

        private static void AddParameter(SqlCommand command, string name, object? value)
        {
            var parameter = command.Parameters.Add(name, GetSqlDbType(name));
            if (parameter.SqlDbType == SqlDbType.Decimal)
            {
                parameter.Precision = 18;
                parameter.Scale = 6;
            }

            if (parameter.SqlDbType == SqlDbType.NVarChar)
                parameter.Size = name == "@ItemLongDesc" ? -1 : 1000;

            parameter.Value = value ?? DBNull.Value;
        }

        private static void EnsureExpectedSyncDatabases(string sourceDatabaseName, string targetDatabaseName)
        {
            if (!string.Equals(sourceDatabaseName, "GUS_2026", StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Intercompany item sync V1 must run from source database GUS_2026.");

            if (!string.Equals(targetDatabaseName, "ASAG_2026", StringComparison.OrdinalIgnoreCase)
                && !string.Equals(targetDatabaseName, "ASA_2026", StringComparison.OrdinalIgnoreCase))
            {
                throw new ArgumentException("Intercompany item sync V1 target database must be ASAG_2026 or ASA_2026.");
            }

            if (string.Equals(sourceDatabaseName, targetDatabaseName, StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Intercompany item sync source and target databases must be different.");
        }

        private List<string> GetConfiguredTargetCodes()
        {
            var targetCodes = _configuration.GetSection("InterCompany:ItemSyncTargets")
                .GetChildren()
                .Select(c => c.Value?.Trim())
                .Where(v => !string.IsNullOrWhiteSpace(v))
                .Select(v => v!)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            if (targetCodes.Count == 0 && !string.IsNullOrWhiteSpace(_configuration.GetConnectionString(LegacyTargetConnectionStringName)))
                targetCodes.Add(LegacyTargetCode);

            if (targetCodes.Count == 0)
                throw new ArgumentException("InterCompany:ItemSyncTargets is required, or configure legacy ConnectionStrings:IntercompanyTarget for ASA.");

            return targetCodes;
        }

        private IntercompanyItemSyncTarget ResolveTarget(string targetCode)
        {
            if (string.IsNullOrWhiteSpace(targetCode))
                throw new ArgumentException("Intercompany item sync target code is required.");

            var configuredTarget = GetConfiguredTargetCodes()
                .FirstOrDefault(t => string.Equals(t, targetCode.Trim(), StringComparison.OrdinalIgnoreCase));

            if (configuredTarget == null)
                throw new ArgumentException($"Intercompany item sync target {targetCode} is not configured.");

            var connectionString = GetTargetConnectionString(configuredTarget);
            if (string.IsNullOrWhiteSpace(connectionString))
                throw new ArgumentException($"ConnectionStrings:{configuredTarget} is required for intercompany item sync target {configuredTarget}.");

            return new IntercompanyItemSyncTarget(configuredTarget, connectionString);
        }

        private string? GetTargetConnectionString(string targetCode)
        {
            var connectionString = _configuration.GetConnectionString(targetCode);
            if (!string.IsNullOrWhiteSpace(connectionString))
                return connectionString;

            if (string.Equals(targetCode, LegacyTargetCode, StringComparison.OrdinalIgnoreCase))
                return _configuration.GetConnectionString(LegacyTargetConnectionStringName);

            return null;
        }

        private static SqlDbType GetSqlDbType(string name)
        {
            return name switch
            {
                "@ItemId" or "@ItemUnitId" or "@CategoryId" or "@StorageId" or "@BaseUnitId" or "@MultipleToBase" => SqlDbType.Int,
                "@FactorToBase" or "@PricePercentToBase" or "@PaletteFactor" or "@SaftyInventory" or "@ActualSaftyInventory"
                    or "@RefillInventory" or "@CaseWeight" or "@CaseLength" or "@CaseWidth" or "@CaseHeight"
                    or "@CaseVolumeInCubicFeet" or "@CaseVolumeInCubicMeter" => SqlDbType.Decimal,
                "@IsBaseUnit" or "@IsDefaultSalesUnit" or "@Inactive" or "@IsDeleted" or "@IsTaxable" or "@IsHRTaxable"
                    or "@IsHighlighted" or "@IsImport" or "@IsWeightItem" or "@IsMetricWeight" or "@IsMetricDimension"
                    or "@IsVolumeManual" => SqlDbType.Bit,
                _ => SqlDbType.NVarChar
            };
        }

        private static List<BaseUnitIssue> GetBaseUnitIssues(string dbRole, Dictionary<int, ItemSnapshot> items, Dictionary<int, ItemUnitSnapshot> units)
        {
            return items.Values
                .Where(i => i.BaseUnitId.HasValue
                    && (!units.TryGetValue(i.BaseUnitId.Value, out var unit) || unit.ItemId != i.ItemId))
                .Select(i => new BaseUnitIssue(dbRole, i.ItemId, i.BaseUnitId))
                .ToList();
        }

        private static List<CountIssue> GetBaseUnitCountIssues(string dbRole, Dictionary<int, ItemSnapshot> items, Dictionary<int, ItemUnitSnapshot> units)
        {
            var baseUnitCounts = units.Values
                .Where(u => !u.Inactive && u.IsBaseUnit)
                .GroupBy(u => u.ItemId)
                .ToDictionary(g => g.Key, g => g.Count());

            return items.Keys
                .Select(itemId => new CountIssue(dbRole, itemId, baseUnitCounts.GetValueOrDefault(itemId)))
                .Where(i => i.CountValue != 1)
                .ToList();
        }

        private static List<CountIssue> GetDefaultSalesUnitCountIssues(string dbRole, Dictionary<int, ItemUnitSnapshot> units)
        {
            return units.Values
                .Where(u => !u.Inactive && u.IsDefaultSalesUnit)
                .GroupBy(u => u.ItemId)
                .Where(g => g.Count() > 1)
                .Select(g => new CountIssue(dbRole, g.Key, g.Count()))
                .ToList();
        }

        private static void AddCheck(IntercompanyItemSyncPreviewDto preview, string checkName, int countValue, bool isBlocker)
        {
            preview.Checks.Add(new IntercompanyItemSyncCheckDto
            {
                CheckName = checkName,
                CountValue = countValue,
                IsBlocker = isBlocker
            });
        }

        private static void AddSamples<T>(
            IntercompanyItemSyncPreviewDto preview,
            string blockerType,
            IEnumerable<T> rows,
            bool isBlocker,
            Func<T, int?> itemId,
            Func<T, int?>? itemUnitId,
            Func<T, string?>? sourceValue,
            Func<T, string?>? targetValue,
            string message)
        {
            preview.Rows.AddRange(rows.Take(MaxBlockerRows).Select(row => new IntercompanyItemSyncPreviewRowDto
            {
                RowType = blockerType,
                ItemId = itemId(row),
                ItemUnitId = itemUnitId?.Invoke(row),
                SourceValue = sourceValue?.Invoke(row),
                TargetValue = targetValue?.Invoke(row),
                IsBlocker = isBlocker,
                Message = message
            }));
        }

        private static void AddItemConflictSamples(IntercompanyItemSyncPreviewDto preview, IEnumerable<ItemSnapshot> rows, Dictionary<int, ItemSnapshot> targetItems)
        {
            preview.Rows.AddRange(rows.Take(MaxBlockerRows).Select(source =>
            {
                var target = targetItems[source.ItemId];
                return new IntercompanyItemSyncPreviewRowDto
                {
                    RowType = "ItemIdentityConflict",
                    ItemId = source.ItemId,
                    SourceValue = FormatItemIdentity(source),
                    TargetValue = FormatItemIdentity(target),
                    IsBlocker = true,
                    Message = "Same ItemId has different identity/dependency fields."
                };
            }));
        }

        private static void AddItemUnitConflictSamples(IntercompanyItemSyncPreviewDto preview, IEnumerable<ItemUnitSnapshot> rows, Dictionary<int, ItemUnitSnapshot> targetUnits)
        {
            preview.Rows.AddRange(rows.Take(MaxBlockerRows).Select(source =>
            {
                var target = targetUnits[source.ItemUnitId];
                return new IntercompanyItemSyncPreviewRowDto
                {
                    RowType = "ItemUnitImmutableConflict",
                    ItemId = source.ItemId,
                    ItemUnitId = source.ItemUnitId,
                    SourceValue = FormatItemUnitIdentity(source),
                    TargetValue = FormatItemUnitIdentity(target),
                    IsBlocker = true,
                    Message = "Same ItemUnitId has different immutable unit fields."
                };
            }));
        }

        private static void AddDependencySamples(IntercompanyItemSyncPreviewDto preview, string blockerType, IEnumerable<int> ids, Dictionary<int, string?> sourceLookup, Dictionary<int, string?> targetLookup)
        {
            preview.Rows.AddRange(ids.Take(MaxBlockerRows).Select(id => new IntercompanyItemSyncPreviewRowDto
            {
                RowType = blockerType,
                SourceValue = $"{id}:{sourceLookup.GetValueOrDefault(id)}",
                TargetValue = targetLookup.TryGetValue(id, out var targetValue) ? $"{id}:{targetValue}" : null,
                IsBlocker = true,
                Message = "Target lookup row is missing or has a different display value."
            }));
        }

        private static void AddBaseUnitIssueSamples(IntercompanyItemSyncPreviewDto preview, IEnumerable<BaseUnitIssue> rows)
        {
            preview.Rows.AddRange(rows.Take(MaxBlockerRows).Select(row => new IntercompanyItemSyncPreviewRowDto
            {
                RowType = "BaseUnitReferenceIssue",
                ItemId = row.ItemId,
                ItemUnitId = row.BaseUnitId,
                SourceValue = row.DbRole,
                IsBlocker = true,
                Message = "Item.BaseUnitId does not point to a matching ItemUnit for the same item."
            }));
        }

        private static void AddCountIssueSamples(IntercompanyItemSyncPreviewDto preview, string blockerType, IEnumerable<CountIssue> rows)
        {
            preview.Rows.AddRange(rows.Take(MaxBlockerRows).Select(row => new IntercompanyItemSyncPreviewRowDto
            {
                RowType = blockerType,
                ItemId = row.ItemId,
                SourceValue = row.DbRole,
                TargetValue = row.CountValue.ToString(),
                IsBlocker = true,
                Message = "Unit count rule failed for this item."
            }));
        }

        private static string FormatItemIdentity(ItemSnapshot item)
        {
            return $"{item.ItemCode}|{item.ItemName}|{item.ItemType}|BaseUnit:{item.BaseUnitId}|Category:{item.CategoryId}|Storage:{item.StorageId}";
        }

        private static string FormatItemUnitIdentity(ItemUnitSnapshot unit)
        {
            return $"Item:{unit.ItemId}|Unit:{unit.Unit}|Factor:{unit.FactorToBase}|Multiple:{unit.MultipleToBase}|Base:{unit.IsBaseUnit}";
        }

        private static bool TextEquals(string? left, string? right)
        {
            return string.Equals(left ?? string.Empty, right ?? string.Empty, StringComparison.Ordinal);
        }

        private static string? GetNullableString(SqlDataReader reader, string columnName)
        {
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
        }

        private static string GetString(SqlDataReader reader, string columnName)
        {
            return reader.GetString(reader.GetOrdinal(columnName));
        }

        private static int GetInt32(SqlDataReader reader, string columnName)
        {
            return reader.GetInt32(reader.GetOrdinal(columnName));
        }

        private static int? GetNullableInt32(SqlDataReader reader, string columnName)
        {
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? null : reader.GetInt32(ordinal);
        }

        private static decimal GetDecimal(SqlDataReader reader, string columnName)
        {
            return reader.GetDecimal(reader.GetOrdinal(columnName));
        }

        private static decimal? GetNullableDecimal(SqlDataReader reader, string columnName)
        {
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? null : reader.GetDecimal(ordinal);
        }

        private static bool GetBoolean(SqlDataReader reader, string columnName)
        {
            return reader.GetBoolean(reader.GetOrdinal(columnName));
        }

        private record ItemSnapshot(
            int ItemId,
            string? ItemType,
            string ItemCode,
            string? ItemName,
            string? ItemName2,
            string? ItemSearchTag,
            string? ItemLongDesc,
            string? ItemBoxDesc,
            string? ItemBrand,
            string? SetPacking,
            string? PackSize,
            int? BaseUnitId,
            int? CategoryId,
            int? StorageId,
            decimal? PaletteFactor,
            decimal? SaftyInventory,
            decimal? ActualSaftyInventory,
            decimal? RefillInventory,
            bool IsWeightItem,
            bool IsMetricWeight,
            bool IsMetricDimension,
            bool IsVolumeManual,
            decimal? CaseWeight,
            decimal? CaseLength,
            decimal? CaseWidth,
            decimal? CaseHeight,
            decimal? CaseVolumeInCubicFeet,
            decimal? CaseVolumeInCubicMeter,
            bool Inactive,
            bool IsDeleted,
            bool IsTaxable,
            bool IsHRTaxable,
            bool IsHighlighted,
            bool IsImport);

        private record ItemUnitSnapshot(
            int ItemUnitId,
            int ItemId,
            string Unit,
            decimal FactorToBase,
            decimal? PricePercentToBase,
            int MultipleToBase,
            bool IsBaseUnit,
            bool IsDefaultSalesUnit,
            string? Barcode,
            bool Inactive);

        private record BaseUnitIssue(string DbRole, int ItemId, int? BaseUnitId);

        private record CountIssue(string DbRole, int ItemId, int CountValue);

        private record IntercompanyItemSyncTarget(string TargetCode, string ConnectionString);
    }
}
