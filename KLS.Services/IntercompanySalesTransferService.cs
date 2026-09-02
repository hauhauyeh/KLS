using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models.Intercompany;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Data;

namespace KLS.Services
{
    public class IntercompanySalesTransferService : BaseService, IIntercompanySalesTransferService
    {
        private const string ExpectedSourceDatabaseName = "GUS_2026";
        private const string ExpectedTargetDatabaseName = "ASAG_2026";
        private const string DefaultTargetCode = "ASAG";
        private const int DefaultSourcePayeeId = 300302;
        private const int MaxPreviewRows = 50;
        private const string SourcePayeeSettingKey = "INTERCOMPANY_SALES_TRANSFER_PAYEE_ID_ASAG";
        private const string CreateLockResource = "IntercompanySalesTransfer_Create_ASAG";

        private static readonly int[] EligibleTargetStageIds = { 3, 4 };

        private readonly IConfiguration _configuration;

        public IntercompanySalesTransferService(IUnitOfWork uow, IConfiguration configuration) : base(uow)
        {
            _configuration = configuration;
        }

        public List<IntercompanySalesTransferTargetDto> Targets()
        {
            return GetConfiguredTargetCodes()
                .Select(targetCode =>
                {
                    var connectionString = GetTargetConnectionString(targetCode);
                    if (string.IsNullOrWhiteSpace(connectionString))
                        throw new ArgumentException($"ConnectionStrings:{targetCode} is required for intercompany sales transfer target {targetCode}.");

                    return new IntercompanySalesTransferTargetDto
                    {
                        TargetCode = targetCode,
                        DisplayName = targetCode
                    };
                })
                .ToList();
        }

        public IntercompanySalesTransferPreviewDto Preview(string targetCode, DateOnly fromShipDate, DateOnly toShipDate)
        {
            if (fromShipDate > toShipDate)
                throw new ArgumentException("From ship date must be before or equal to to ship date.");

            using var connections = OpenValidatedConnections(targetCode);
            var schemaExists = TransferSchemaExists(connections.SourceConnection);
            var sourcePayeeId = ResolveSourcePayeeId(connections.SourceConnection);
            var sourcePayeeIsValid = SourcePayeeIsCustomer(connections.SourceConnection, sourcePayeeId);
            var targetRows = LoadTargetSalesRows(connections.TargetConnection, fromShipDate, toShipDate);
            var transferredTargetSalesIds = schemaExists
                ? LoadTransferredTargetSalesIds(connections.SourceConnection, connections.TargetCode, connections.TargetConnection.Database)
                : new HashSet<int>();
            var eligibleRows = targetRows
                .Where(r => !transferredTargetSalesIds.Contains(r.TargetSalesId))
                .ToList();
            var sourceItems = LoadSourceItems(connections.SourceConnection, eligibleRows.Select(r => r.ItemId));
            var sourceUnits = LoadSourceUnits(connections.SourceConnection, eligibleRows.Select(r => r.ItemUnitId));

            var missingSourceItems = eligibleRows
                .Where(r => !sourceItems.ContainsKey(r.ItemId))
                .GroupBy(r => r.ItemId)
                .Select(g => g.First())
                .ToList();
            var missingSourceUnits = eligibleRows
                .Where(r => !sourceUnits.ContainsKey(r.ItemUnitId))
                .GroupBy(r => r.ItemUnitId)
                .Select(g => g.First())
                .ToList();
            var sourceUnitItemMismatches = eligibleRows
                .Where(r => sourceUnits.TryGetValue(r.ItemUnitId, out var unit) && unit.ItemId != r.ItemId)
                .GroupBy(r => r.ItemUnitId)
                .Select(g => g.First())
                .ToList();
            var nonInventoryItems = eligibleRows
                .Where(r => sourceItems.TryGetValue(r.ItemId, out var item) && IsNonInventory(item.ItemType))
                .GroupBy(r => r.ItemId)
                .Select(g => g.First())
                .ToList();
            var missingRecentCost = eligibleRows
                .Where(r => sourceUnits.TryGetValue(r.ItemUnitId, out var unit) && (!unit.RecentCost.HasValue || unit.RecentCost.Value == 0))
                .GroupBy(r => r.ItemUnitId)
                .Select(g => g.First())
                .ToList();

            var validRows = eligibleRows
                .Where(r =>
                    sourceItems.TryGetValue(r.ItemId, out var item)
                    && !IsNonInventory(item.ItemType)
                    && sourceUnits.TryGetValue(r.ItemUnitId, out var unit)
                    && unit.RecentCost.HasValue
                    && unit.RecentCost.Value != 0)
                .ToList();
            var groupedLineCount = eligibleRows
                .GroupBy(r => new { r.TargetShipDate, r.ItemId, r.ItemUnitId, r.Unit })
                .Count();
            var sourceSalesCount = eligibleRows
                .Select(r => r.TargetShipDate)
                .Distinct()
                .Count();

            var preview = new IntercompanySalesTransferPreviewDto
            {
                TargetCode = connections.TargetCode,
                SourceDatabaseName = connections.SourceConnection.Database,
                TargetDatabaseName = connections.TargetConnection.Database,
                FromShipDate = fromShipDate,
                ToShipDate = toShipDate,
                EligibleTargetSalesCount = eligibleRows.Select(r => r.TargetSalesId).Distinct().Count(),
                SkippedTransferredSalesCount = targetRows.Where(r => transferredTargetSalesIds.Contains(r.TargetSalesId)).Select(r => r.TargetSalesId).Distinct().Count(),
                ItemLineCount = eligibleRows.Count,
                GroupedLineCount = groupedLineCount,
                EstimatedSourceSalesCount = sourceSalesCount,
                TotalQty = validRows.Sum(r => r.ShipQty),
                TotalAmount = validRows.Sum(r => sourceUnits[r.ItemUnitId].RecentCost!.Value * 1.05m * r.ShipQty)
            };

            AddCheck(preview, "TransferSchemaMissing", schemaExists ? 0 : 1, true);
            AddCheck(preview, "SourceIntercompanyCustomerMissing", sourcePayeeIsValid ? 0 : 1, true);
            AddCheck(preview, "EligibleTargetSales", preview.EligibleTargetSalesCount, false);
            AddCheck(preview, "NoEligibleTargetSales", preview.EligibleTargetSalesCount == 0 ? 1 : 0, true);
            AddCheck(preview, "SkippedAlreadyTransferredTargetSales", preview.SkippedTransferredSalesCount, false);
            AddCheck(preview, "MissingSourceItem", missingSourceItems.Count, true);
            AddCheck(preview, "MissingSourceItemUnit", missingSourceUnits.Count, true);
            AddCheck(preview, "SourceItemUnitItemMismatch", sourceUnitItemMismatches.Count, true);
            AddCheck(preview, "NonInventorySourceItem", nonInventoryItems.Count, true);
            AddCheck(preview, "MissingSourceItemUnitRecentCost", missingRecentCost.Count, true);
            AddCheck(preview, "GroupedOutputLines", preview.GroupedLineCount, false);
            AddCheck(preview, "EstimatedSourceSalesDocs", preview.EstimatedSourceSalesCount, false);

            if (!schemaExists)
                AddSystemRow(preview, "TransferSchemaMissing", true, "Run the intercompany sales transfer schema before preview/create.");

            if (!sourcePayeeIsValid)
                AddSystemRow(preview, "SourceIntercompanyCustomerMissing", true, $"Source customer/payee {sourcePayeeId} is missing or is not a customer.");

            if (preview.EligibleTargetSalesCount == 0)
                AddSystemRow(preview, "NoEligibleTargetSales", true, "No untransferred target sales found for the selected ship date range.");

            AddIssueSamples(preview, "MissingSourceItem", missingSourceItems, true, "Target item id is missing in source.");
            AddIssueSamples(preview, "MissingSourceItemUnit", missingSourceUnits, true, "Target item unit id is missing in source.");
            AddIssueSamples(preview, "SourceItemUnitItemMismatch", sourceUnitItemMismatches, true, "Source item unit id belongs to a different item.");
            AddIssueSamples(preview, "NonInventorySourceItem", nonInventoryItems, true, "Source item is non-inventory; transfer would not reduce inventory.");
            AddIssueSamples(preview, "MissingSourceItemUnitRecentCost", missingRecentCost, true, "Source item unit recent cost is missing or zero.");
            AddEligibleSamples(preview, eligibleRows, sourceUnits);

            return preview;
        }

        public IntercompanySalesTransferCreateResultDto Create(IntercompanySalesTransferCreateReq req, int empId)
        {
            if (req == null)
                throw new ArgumentException("Intercompany sales transfer request is required.");

            if (empId <= 0)
                throw new ArgumentException("Employee id is required.");

            if (req.FromShipDate > req.ToShipDate)
                throw new ArgumentException("From ship date must be before or equal to to ship date.");

            var preview = Preview(req.TargetCode, req.FromShipDate, req.ToShipDate);
            if (preview.HasBlockers)
                throw new ArgumentException("Intercompany sales transfer has preview blockers. Resolve blockers before create.");

            using var connections = OpenValidatedConnections(req.TargetCode);
            var lockTaken = false;
            var batchId = 0;
            var sourcePayeeId = 0;

            try
            {
                AcquireCreateLock(connections.SourceConnection);
                lockTaken = true;

                preview = Preview(req.TargetCode, req.FromShipDate, req.ToShipDate);
                if (preview.HasBlockers)
                    throw new ArgumentException("Intercompany sales transfer has preview blockers. Resolve blockers before create.");

                sourcePayeeId = ResolveSourcePayeeId(connections.SourceConnection);
                var targetRows = LoadTargetSalesRows(connections.TargetConnection, req.FromShipDate, req.ToShipDate);
                var transferredTargetSalesIds = LoadTransferredTargetSalesIds(
                    connections.SourceConnection,
                    connections.TargetCode,
                    connections.TargetConnection.Database);
                var eligibleRows = targetRows
                    .Where(r => !transferredTargetSalesIds.Contains(r.TargetSalesId))
                    .ToList();

                if (eligibleRows.Count == 0)
                    throw new ArgumentException("No untransferred target sales found for the selected ship date range.");

                var sourceUnits = LoadSourceUnits(connections.SourceConnection, eligibleRows.Select(r => r.ItemUnitId));
                var lineGroups = eligibleRows
                    .GroupBy(r => new { r.TargetShipDate, r.ItemId, r.ItemUnitId, Unit = r.Unit ?? string.Empty })
                    .OrderBy(g => g.Key.TargetShipDate)
                    .ThenBy(g => g.Key.ItemId)
                    .ThenBy(g => g.Key.ItemUnitId)
                    .ToList();
                var totalQty = lineGroups.Sum(g => g.Sum(r => r.ShipQty));
                var totalAmount = lineGroups.Sum(g =>
                    RoundMoney(sourceUnits[g.Key.ItemUnitId].RecentCost!.Value * 1.05m) * g.Sum(r => r.ShipQty));

                batchId = InsertBatch(
                    connections.SourceConnection,
                    connections.TargetCode,
                    connections.TargetConnection.Database,
                    req.FromShipDate,
                    req.ToShipDate,
                    empId);

                var createdSales = new List<IntercompanySalesTransferCreatedSalesDto>();
                foreach (var shipDateGroup in lineGroups.GroupBy(g => g.Key.TargetShipDate).OrderBy(g => g.Key))
                {
                    ClearIntercompanyTempSales(connections.SourceConnection, empId, sourcePayeeId);

                    var lineId = 1;
                    foreach (var lineGroup in shipDateGroup)
                    {
                        if (!sourceUnits.TryGetValue(lineGroup.Key.ItemUnitId, out var sourceUnit)
                            || !sourceUnit.RecentCost.HasValue
                            || sourceUnit.RecentCost.Value == 0)
                        {
                            throw new ArgumentException($"Source item unit {lineGroup.Key.ItemUnitId} recent cost is missing or zero.");
                        }

                        var qty = lineGroup.Sum(r => r.ShipQty);
                        var unitPrice = RoundMoney(sourceUnit.RecentCost.Value * 1.05m);
                        InsertTempSalesLine(
                            connections.SourceConnection,
                            empId,
                            sourcePayeeId,
                            lineId++,
                            lineGroup.Key.ItemId,
                            lineGroup.Key.ItemUnitId,
                            sourceUnit.Unit ?? lineGroup.Key.Unit,
                            qty,
                            unitPrice,
                            sourceUnit.FactorToBase,
                            $"IC {connections.TargetCode} {shipDateGroup.Key:yyyy-MM-dd}");
                    }

                    var sourceSalesId = CreateSourceSales(
                        connections.SourceConnection,
                        sourcePayeeId,
                        shipDateGroup.Key,
                        connections.TargetCode,
                        empId);
                    var sourceSalesNumber = LoadSourceSalesNumber(connections.SourceConnection, sourceSalesId);
                    var targetSalesRows = shipDateGroup
                        .SelectMany(g => g)
                        .GroupBy(r => r.TargetSalesId)
                        .Select(g => g.First())
                        .ToList();

                    InsertTransferSourceRows(
                        connections.SourceConnection,
                        batchId,
                        connections.TargetCode,
                        connections.TargetConnection.Database,
                        sourceSalesId,
                        sourceSalesNumber,
                        targetSalesRows);

                    createdSales.Add(new IntercompanySalesTransferCreatedSalesDto
                    {
                        SourceSalesId = sourceSalesId,
                        SourceSalesNumber = sourceSalesNumber,
                        ShipDate = shipDateGroup.Key,
                        TargetSalesCount = targetSalesRows.Count,
                        LineCount = shipDateGroup.Count(),
                        TotalQty = shipDateGroup.Sum(g => g.Sum(r => r.ShipQty)),
                        TotalAmount = shipDateGroup.Sum(g =>
                            RoundMoney(sourceUnits[g.Key.ItemUnitId].RecentCost!.Value * 1.05m) * g.Sum(r => r.ShipQty))
                    });
                }

                UpdateBatchCompleted(
                    connections.SourceConnection,
                    batchId,
                    createdSales.Count,
                    eligibleRows.Select(r => r.TargetSalesId).Distinct().Count(),
                    lineGroups.Count,
                    totalQty,
                    totalAmount);

                return new IntercompanySalesTransferCreateResultDto
                {
                    TargetCode = connections.TargetCode,
                    SourceDatabaseName = connections.SourceConnection.Database,
                    TargetDatabaseName = connections.TargetConnection.Database,
                    BatchId = batchId,
                    SourceSalesCount = createdSales.Count,
                    TargetSalesCount = eligibleRows.Select(r => r.TargetSalesId).Distinct().Count(),
                    LineCount = lineGroups.Count,
                    TotalQty = totalQty,
                    TotalAmount = totalAmount,
                    CreatedSales = createdSales
                };
            }
            catch (Exception ex)
            {
                if (batchId > 0)
                    MarkBatchFailed(connections.SourceConnection, batchId, ex.Message);

                if (sourcePayeeId > 0)
                    ClearIntercompanyTempSales(connections.SourceConnection, empId, sourcePayeeId);

                throw new ArgumentException($"Intercompany sales transfer create failed: {ex.Message}", ex);
            }
            finally
            {
                if (lockTaken)
                {
                    try
                    {
                        ReleaseCreateLock(connections.SourceConnection);
                    }
                    catch
                    {
                        // Do not hide the original create result/error; the SQL session releases this lock on dispose.
                    }
                }
            }
        }

        private static void AcquireCreateLock(SqlConnection sourceConnection)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = @"
DECLARE @LockResult int;
EXEC @LockResult = sp_getapplock
    @Resource = @Resource,
    @LockMode = 'Exclusive',
    @LockOwner = 'Session',
    @LockTimeout = 0;
SELECT @LockResult;";
            AddParameter(command, "@Resource", CreateLockResource);

            var lockResult = Convert.ToInt32(command.ExecuteScalar());
            if (lockResult < 0)
                throw new ArgumentException("Another intercompany sales transfer is already running.");
        }

        private static void ReleaseCreateLock(SqlConnection sourceConnection)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = "EXEC sp_releaseapplock @Resource = @Resource, @LockOwner = 'Session'";
            AddParameter(command, "@Resource", CreateLockResource);
            command.ExecuteNonQuery();
        }

        private static int InsertBatch(
            SqlConnection sourceConnection,
            string targetCode,
            string targetDatabaseName,
            DateOnly fromShipDate,
            DateOnly toShipDate,
            int empId)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = @"
INSERT INTO dbo.IntercompanySalesTransferBatch
    (TargetCode, TargetDatabaseName, FromShipDate, ToShipDate, Status, CreatedBy)
OUTPUT inserted.BatchId
VALUES
    (@TargetCode, @TargetDatabaseName, @FromShipDate, @ToShipDate, N'Previewed', @CreatedBy)";
            AddParameter(command, "@TargetCode", targetCode);
            AddParameter(command, "@TargetDatabaseName", targetDatabaseName);
            AddParameter(command, "@FromShipDate", fromShipDate.ToDateTime(TimeOnly.MinValue));
            AddParameter(command, "@ToShipDate", toShipDate.ToDateTime(TimeOnly.MinValue));
            AddParameter(command, "@CreatedBy", empId);

            return Convert.ToInt32(command.ExecuteScalar());
        }

        private static void UpdateBatchCompleted(
            SqlConnection sourceConnection,
            int batchId,
            int sourceSalesCount,
            int targetSalesCount,
            int lineCount,
            decimal totalQty,
            decimal totalAmount)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = @"
UPDATE dbo.IntercompanySalesTransferBatch
SET Status = N'Completed',
    SourceSalesCount = @SourceSalesCount,
    TargetSalesCount = @TargetSalesCount,
    LineCount = @LineCount,
    TotalQty = @TotalQty,
    TotalAmount = @TotalAmount,
    CompletedAt = GETUTCDATE()
WHERE BatchId = @BatchId";
            AddParameter(command, "@BatchId", batchId);
            AddParameter(command, "@SourceSalesCount", sourceSalesCount);
            AddParameter(command, "@TargetSalesCount", targetSalesCount);
            AddParameter(command, "@LineCount", lineCount);
            AddParameter(command, "@TotalQty", totalQty);
            AddParameter(command, "@TotalAmount", totalAmount);
            command.ExecuteNonQuery();
        }

        private static void MarkBatchFailed(SqlConnection sourceConnection, int batchId, string errorMessage)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = @"
UPDATE dbo.IntercompanySalesTransferBatch
SET Status = N'Failed',
    ErrorMessage = @ErrorMessage,
    CompletedAt = GETUTCDATE()
WHERE BatchId = @BatchId
  AND Status <> N'Completed'";
            AddParameter(command, "@BatchId", batchId);
            AddParameter(command, "@ErrorMessage", errorMessage.Length > 1000 ? errorMessage[..1000] : errorMessage);
            command.ExecuteNonQuery();
        }

        private static void ClearIntercompanyTempSales(SqlConnection sourceConnection, int empId, int payeeId)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = @"
DELETE FROM dbo.TempSales
WHERE EmpId = @EmpId
  AND PayeeId = @PayeeId
  AND SalesId = 0";
            AddParameter(command, "@EmpId", empId);
            AddParameter(command, "@PayeeId", payeeId);
            command.ExecuteNonQuery();
        }

        private static void InsertTempSalesLine(
            SqlConnection sourceConnection,
            int empId,
            int payeeId,
            int lineId,
            int itemId,
            int itemUnitId,
            string unit,
            decimal qty,
            decimal unitPrice,
            decimal? factorToBase,
            string notes)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = @"
INSERT INTO dbo.TempSales
(
    EmpId, SalesId, PayeeId, LineId, LineType,
    ItemId, AccountId, ItemUnitId, Unit,
    IsFree, IsOut, IsCRCG,
    OrdQty, ShipQty, BillQty,
    UnitPrice, Notes, IsTaxable, OrgPrice,
    DiscountPercent, FactorToBase,
    ChangeStatus, IsStrike, CartLineType, IsSystemManaged, DisplaySort,
    IsManualPrice
)
VALUES
(
    @EmpId, 0, @PayeeId, @LineId, N'I',
    @ItemId, NULL, @ItemUnitId, @Unit,
    0, 0, 0,
    @Qty, @Qty, @Qty,
    @UnitPrice, @Notes, 0, @UnitPrice,
    NULL, @FactorToBase,
    N'I', 0, N'MAIN', 0, @LineId,
    1
)";
            AddParameter(command, "@EmpId", empId);
            AddParameter(command, "@PayeeId", payeeId);
            AddParameter(command, "@LineId", lineId);
            AddParameter(command, "@ItemId", itemId);
            AddParameter(command, "@ItemUnitId", itemUnitId);
            AddParameter(command, "@Unit", unit);
            AddParameter(command, "@Qty", qty);
            AddParameter(command, "@UnitPrice", unitPrice);
            AddParameter(command, "@Notes", notes);
            AddParameter(command, "@FactorToBase", factorToBase ?? 1m);
            command.ExecuteNonQuery();
        }

        private static int CreateSourceSales(
            SqlConnection sourceConnection,
            int sourcePayeeId,
            DateOnly shipDate,
            string targetCode,
            int empId)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = @"
EXEC dbo.Sales_Insert
    @SalesId = @SalesId,
    @PayeeId = @PayeeId,
    @ShipDate = @ShipDate,
    @ShipRoute = @ShipRoute,
    @Instruction = @Instruction,
    @StageId = @StageId,
    @EmpId = @EmpId,
    @NewSalesId = @NewSalesId OUTPUT,
    @DocType = @DocType,
    @ParentSalesNumber = @ParentSalesNumber,
    @AllowNoParentOverride = @AllowNoParentOverride";
            AddParameter(command, "@SalesId", 0);
            AddParameter(command, "@PayeeId", sourcePayeeId);
            AddParameter(command, "@ShipDate", shipDate.ToDateTime(TimeOnly.MinValue));
            AddParameter(command, "@ShipRoute", null);
            AddParameter(command, "@Instruction", $"Intercompany {targetCode}");
            AddParameter(command, "@StageId", 4);
            AddParameter(command, "@EmpId", empId);
            AddParameter(command, "@DocType", "SO");
            AddParameter(command, "@ParentSalesNumber", null);
            AddParameter(command, "@AllowNoParentOverride", 0);

            var newSalesId = command.Parameters.Add("@NewSalesId", SqlDbType.Int);
            newSalesId.Direction = ParameterDirection.Output;

            command.ExecuteNonQuery();
            return Convert.ToInt32(newSalesId.Value);
        }

        private static int? LoadSourceSalesNumber(SqlConnection sourceConnection, int sourceSalesId)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = @"
SELECT SalesNumber
FROM dbo.Sales
WHERE SalesId = @SalesId";
            AddParameter(command, "@SalesId", sourceSalesId);

            var value = command.ExecuteScalar();
            return value == null || value == DBNull.Value ? null : Convert.ToInt32(value);
        }

        private static void InsertTransferSourceRows(
            SqlConnection sourceConnection,
            int batchId,
            string targetCode,
            string targetDatabaseName,
            int sourceSalesId,
            int? sourceSalesNumber,
            IEnumerable<TargetSalesLine> targetSalesRows)
        {
            foreach (var row in targetSalesRows)
            {
                using var command = sourceConnection.CreateCommand();
                command.CommandText = @"
INSERT INTO dbo.IntercompanySalesTransferSource
(
    BatchId, TargetCode, TargetDatabaseName,
    TargetSalesId, TargetSalesNumber, TargetSalesDocNumber,
    TargetShipDate, TargetStageId,
    SourceSalesId, SourceSalesNumber, TargetSalesTotal
)
VALUES
(
    @BatchId, @TargetCode, @TargetDatabaseName,
    @TargetSalesId, @TargetSalesNumber, @TargetSalesDocNumber,
    @TargetShipDate, @TargetStageId,
    @SourceSalesId, @SourceSalesNumber, @TargetSalesTotal
)";
                AddParameter(command, "@BatchId", batchId);
                AddParameter(command, "@TargetCode", targetCode);
                AddParameter(command, "@TargetDatabaseName", targetDatabaseName);
                AddParameter(command, "@TargetSalesId", row.TargetSalesId);
                AddParameter(command, "@TargetSalesNumber", row.TargetSalesNumber);
                AddParameter(command, "@TargetSalesDocNumber", row.TargetSalesDocNumber);
                AddParameter(command, "@TargetShipDate", row.TargetShipDate.ToDateTime(TimeOnly.MinValue));
                AddParameter(command, "@TargetStageId", row.TargetStageId);
                AddParameter(command, "@SourceSalesId", sourceSalesId);
                AddParameter(command, "@SourceSalesNumber", sourceSalesNumber);
                AddParameter(command, "@TargetSalesTotal", row.TargetSalesTotal);
                command.ExecuteNonQuery();
            }
        }

        private static decimal RoundMoney(decimal value)
        {
            return Math.Round(value, 2, MidpointRounding.AwayFromZero);
        }

        private IntercompanySalesTransferConnections OpenValidatedConnections(string targetCode)
        {
            var sourceConnectionString = _configuration.GetConnectionString("Default");
            if (string.IsNullOrWhiteSpace(sourceConnectionString))
                throw new ArgumentException("ConnectionStrings:Default is required.");

            var target = ResolveTarget(targetCode);

            var sourceConnection = new SqlConnection(sourceConnectionString);
            var targetConnection = new SqlConnection(target.ConnectionString);

            try
            {
                sourceConnection.Open();
                targetConnection.Open();
                EnsureExpectedTransferDatabases(sourceConnection.Database, targetConnection.Database);

                return new IntercompanySalesTransferConnections(target.TargetCode, sourceConnection, targetConnection);
            }
            catch
            {
                sourceConnection.Dispose();
                targetConnection.Dispose();
                throw;
            }
        }

        private List<string> GetConfiguredTargetCodes()
        {
            var targetCodes = _configuration.GetSection("InterCompany:SalesTransferTargets")
                .GetChildren()
                .Select(c => c.Value?.Trim())
                .Where(v => !string.IsNullOrWhiteSpace(v))
                .Select(v => v!)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            if (targetCodes.Count > 0)
                return targetCodes;

            return new List<string> { DefaultTargetCode };
        }

        private IntercompanySalesTransferTarget ResolveTarget(string targetCode)
        {
            if (string.IsNullOrWhiteSpace(targetCode))
                throw new ArgumentException("Intercompany sales transfer target code is required.");

            var configuredTarget = GetConfiguredTargetCodes()
                .FirstOrDefault(t => string.Equals(t, targetCode.Trim(), StringComparison.OrdinalIgnoreCase));

            if (configuredTarget == null)
                throw new ArgumentException($"Intercompany sales transfer target {targetCode} is not configured.");

            var connectionString = GetTargetConnectionString(configuredTarget);
            if (string.IsNullOrWhiteSpace(connectionString))
                throw new ArgumentException($"ConnectionStrings:{configuredTarget} is required for intercompany sales transfer target {configuredTarget}.");

            return new IntercompanySalesTransferTarget(configuredTarget, connectionString);
        }

        private string? GetTargetConnectionString(string targetCode)
        {
            var connectionString = _configuration.GetConnectionString(targetCode);
            if (!string.IsNullOrWhiteSpace(connectionString))
                return connectionString;

            return null;
        }

        private static void EnsureExpectedTransferDatabases(string sourceDatabaseName, string targetDatabaseName)
        {
            if (!string.Equals(sourceDatabaseName, ExpectedSourceDatabaseName, StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Intercompany sales transfer V1 must run from source database GUS_2026.");

            if (!string.Equals(targetDatabaseName, ExpectedTargetDatabaseName, StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Intercompany sales transfer V1 target database must be ASAG_2026.");

            if (string.Equals(sourceDatabaseName, targetDatabaseName, StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Intercompany sales transfer source and target databases must be different.");
        }

        private static bool TransferSchemaExists(SqlConnection sourceConnection)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = @"
SELECT CASE
    WHEN OBJECT_ID(N'dbo.IntercompanySalesTransferBatch', N'U') IS NOT NULL
     AND OBJECT_ID(N'dbo.IntercompanySalesTransferSource', N'U') IS NOT NULL
    THEN 1 ELSE 0 END";

            return Convert.ToInt32(command.ExecuteScalar()) == 1;
        }

        private static int ResolveSourcePayeeId(SqlConnection sourceConnection)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = @"
SELECT COALESCE(
    (SELECT TRY_CONVERT(int, SettingValue)
     FROM dbo.SystemSetting
     WHERE SettingKey = @SettingKey),
    @DefaultPayeeId)";
            AddParameter(command, "@SettingKey", SourcePayeeSettingKey);
            AddParameter(command, "@DefaultPayeeId", DefaultSourcePayeeId);

            return Convert.ToInt32(command.ExecuteScalar());
        }

        private static bool SourcePayeeIsCustomer(SqlConnection sourceConnection, int payeeId)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = @"
SELECT CASE WHEN EXISTS
(
    SELECT 1
    FROM dbo.Payee p
    INNER JOIN dbo.Customer c ON c.PayeeId = p.PayeeId
    WHERE p.PayeeId = @PayeeId
)
THEN 1 ELSE 0 END";
            AddParameter(command, "@PayeeId", payeeId);

            return Convert.ToInt32(command.ExecuteScalar()) == 1;
        }

        private static List<TargetSalesLine> LoadTargetSalesRows(SqlConnection targetConnection, DateOnly fromShipDate, DateOnly toShipDate)
        {
            using var command = targetConnection.CreateCommand();
            AddIntListParameters(command, EligibleTargetStageIds.ToList(), "StageId", out var stageIdInClause);
            command.CommandText = @"
SELECT
    s.SalesId AS TargetSalesId,
    s.SalesNumber AS TargetSalesNumber,
    s.SalesDocNumber AS TargetSalesDocNumber,
    s.ShipDate AS TargetShipDate,
    s.StageId AS TargetStageId,
    s.SalesTotal AS TargetSalesTotal,
    sd.ItemId,
    sd.ItemUnitId,
    sd.Unit,
    sd.ShipQty
FROM dbo.Sales s
INNER JOIN dbo.SalesDetail sd ON sd.SalesId = s.SalesId
WHERE s.DocType = 'SO'
  AND s.ShipDate >= @FromShipDate
  AND s.ShipDate <= @ToShipDate
  AND s.StageId IN (" + stageIdInClause + @")
  AND sd.LineType = 'I'
  AND sd.ItemId IS NOT NULL
  AND sd.ItemUnitId IS NOT NULL
  AND ISNULL(sd.ShipQty, 0) <> 0";
            AddParameter(command, "@FromShipDate", fromShipDate.ToDateTime(TimeOnly.MinValue));
            AddParameter(command, "@ToShipDate", toShipDate.ToDateTime(TimeOnly.MinValue));

            var rows = new List<TargetSalesLine>();
            using var reader = command.ExecuteReader();
            while (reader.Read())
            {
                rows.Add(new TargetSalesLine(
                    GetInt32(reader, "TargetSalesId"),
                    GetNullableInt32(reader, "TargetSalesNumber"),
                    GetNullableString(reader, "TargetSalesDocNumber"),
                    GetDateOnly(reader, "TargetShipDate"),
                    GetInt32(reader, "TargetStageId"),
                    GetNullableDecimal(reader, "TargetSalesTotal"),
                    GetInt32(reader, "ItemId"),
                    GetInt32(reader, "ItemUnitId"),
                    GetNullableString(reader, "Unit"),
                    GetDecimal(reader, "ShipQty")));
            }

            return rows;
        }

        private static HashSet<int> LoadTransferredTargetSalesIds(SqlConnection sourceConnection, string targetCode, string targetDatabaseName)
        {
            using var command = sourceConnection.CreateCommand();
            command.CommandText = @"
SELECT TargetSalesId
FROM dbo.IntercompanySalesTransferSource
WHERE TargetCode = @TargetCode
  AND TargetDatabaseName = @TargetDatabaseName";
            AddParameter(command, "@TargetCode", targetCode);
            AddParameter(command, "@TargetDatabaseName", targetDatabaseName);

            var ids = new HashSet<int>();
            using var reader = command.ExecuteReader();
            while (reader.Read())
                ids.Add(reader.GetInt32(0));

            return ids;
        }

        private static Dictionary<int, SourceItemSnapshot> LoadSourceItems(SqlConnection sourceConnection, IEnumerable<int> itemIds)
        {
            var ids = itemIds.Distinct().ToList();
            var rows = new Dictionary<int, SourceItemSnapshot>();
            if (ids.Count == 0)
                return rows;

            using var command = sourceConnection.CreateCommand();
            AddIntListParameters(command, ids, "ItemId", out var inClause);
            command.CommandText = $@"
SELECT ItemId, ItemType
FROM dbo.Item
WHERE ItemId IN ({inClause})";

            using var reader = command.ExecuteReader();
            while (reader.Read())
            {
                var row = new SourceItemSnapshot(
                    GetInt32(reader, "ItemId"),
                    GetNullableString(reader, "ItemType"));
                rows[row.ItemId] = row;
            }

            return rows;
        }

        private static Dictionary<int, SourceItemUnitSnapshot> LoadSourceUnits(SqlConnection sourceConnection, IEnumerable<int> itemUnitIds)
        {
            var ids = itemUnitIds.Distinct().ToList();
            var rows = new Dictionary<int, SourceItemUnitSnapshot>();
            if (ids.Count == 0)
                return rows;

            using var command = sourceConnection.CreateCommand();
            AddIntListParameters(command, ids, "ItemUnitId", out var inClause);
            command.CommandText = $@"
SELECT ItemUnitId, ItemId, Unit, RecentCost, FactorToBase
FROM dbo.ItemUnit
WHERE ItemUnitId IN ({inClause})";

            using var reader = command.ExecuteReader();
            while (reader.Read())
            {
                var row = new SourceItemUnitSnapshot(
                    GetInt32(reader, "ItemUnitId"),
                    GetInt32(reader, "ItemId"),
                    GetNullableString(reader, "Unit"),
                    GetNullableDecimal(reader, "RecentCost"),
                    GetNullableDecimal(reader, "FactorToBase"));
                rows[row.ItemUnitId] = row;
            }

            return rows;
        }

        private static void AddCheck(IntercompanySalesTransferPreviewDto preview, string checkName, int countValue, bool isBlocker)
        {
            preview.Checks.Add(new IntercompanySalesTransferCheckDto
            {
                CheckName = checkName,
                CountValue = countValue,
                IsBlocker = isBlocker
            });
        }

        private static void AddSystemRow(IntercompanySalesTransferPreviewDto preview, string rowType, bool isBlocker, string message)
        {
            if (preview.Rows.Count >= MaxPreviewRows)
                return;

            preview.Rows.Add(new IntercompanySalesTransferPreviewRowDto
            {
                RowType = rowType,
                IsBlocker = isBlocker,
                Message = message
            });
        }

        private static void AddIssueSamples(IntercompanySalesTransferPreviewDto preview, string rowType, IEnumerable<TargetSalesLine> rows, bool isBlocker, string message)
        {
            foreach (var row in rows.Take(MaxPreviewRows - preview.Rows.Count))
            {
                preview.Rows.Add(new IntercompanySalesTransferPreviewRowDto
                {
                    RowType = rowType,
                    TargetSalesId = row.TargetSalesId,
                    TargetSalesNumber = row.TargetSalesNumber,
                    TargetSalesDocNumber = row.TargetSalesDocNumber,
                    TargetShipDate = row.TargetShipDate,
                    TargetStageId = row.TargetStageId,
                    ItemId = row.ItemId,
                    ItemUnitId = row.ItemUnitId,
                    TargetValue = FormatTargetLine(row),
                    IsBlocker = isBlocker,
                    Message = message
                });
            }
        }

        private static void AddEligibleSamples(
            IntercompanySalesTransferPreviewDto preview,
            IEnumerable<TargetSalesLine> rows,
            Dictionary<int, SourceItemUnitSnapshot> sourceUnits)
        {
            foreach (var row in rows.Take(MaxPreviewRows - preview.Rows.Count))
            {
                var sourceValue = sourceUnits.TryGetValue(row.ItemUnitId, out var unit) && unit.RecentCost.HasValue
                    ? $"RecentCost:{unit.RecentCost.Value:0.####} Price:{unit.RecentCost.Value * 1.05m:0.####}"
                    : null;

                preview.Rows.Add(new IntercompanySalesTransferPreviewRowDto
                {
                    RowType = "EligibleTargetSaleLine",
                    TargetSalesId = row.TargetSalesId,
                    TargetSalesNumber = row.TargetSalesNumber,
                    TargetSalesDocNumber = row.TargetSalesDocNumber,
                    TargetShipDate = row.TargetShipDate,
                    TargetStageId = row.TargetStageId,
                    ItemId = row.ItemId,
                    ItemUnitId = row.ItemUnitId,
                    SourceValue = sourceValue,
                    TargetValue = FormatTargetLine(row),
                    IsBlocker = false,
                    Message = "Target line is eligible for transfer."
                });
            }
        }

        private static string FormatTargetLine(TargetSalesLine row)
        {
            return $"Sales:{row.TargetSalesNumber} Ship:{row.TargetShipDate:yyyy-MM-dd} Item:{row.ItemId} Unit:{row.Unit} Qty:{row.ShipQty:0.####}";
        }

        private static bool IsNonInventory(string? itemType)
        {
            return string.Equals(itemType, "NonInventory", StringComparison.OrdinalIgnoreCase);
        }

        private static void AddIntListParameters(SqlCommand command, List<int> values, string prefix, out string inClause)
        {
            var names = new List<string>();
            for (var i = 0; i < values.Count; i++)
            {
                var name = $"@{prefix}{i}";
                names.Add(name);
                AddParameter(command, name, values[i]);
            }

            inClause = string.Join(",", names);
        }

        private static void AddParameter(SqlCommand command, string name, object? value)
        {
            var parameter = command.Parameters.Add(name, value switch
            {
                int _ => SqlDbType.Int,
                decimal _ => SqlDbType.Decimal,
                DateTime _ => SqlDbType.Date,
                _ => SqlDbType.NVarChar
            });

            if (parameter.SqlDbType == SqlDbType.Decimal)
            {
                parameter.Precision = 18;
                parameter.Scale = 6;
            }

            if (parameter.SqlDbType == SqlDbType.NVarChar)
                parameter.Size = 1000;

            parameter.Value = value ?? DBNull.Value;
        }

        private static string? GetNullableString(SqlDataReader reader, string columnName)
        {
            var ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
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

        private static DateOnly GetDateOnly(SqlDataReader reader, string columnName)
        {
            return DateOnly.FromDateTime(reader.GetDateTime(reader.GetOrdinal(columnName)));
        }

        private sealed record IntercompanySalesTransferTarget(string TargetCode, string ConnectionString);

        private sealed record TargetSalesLine(
            int TargetSalesId,
            int? TargetSalesNumber,
            string? TargetSalesDocNumber,
            DateOnly TargetShipDate,
            int TargetStageId,
            decimal? TargetSalesTotal,
            int ItemId,
            int ItemUnitId,
            string? Unit,
            decimal ShipQty);

        private sealed record SourceItemSnapshot(int ItemId, string? ItemType);

        private sealed record SourceItemUnitSnapshot(int ItemUnitId, int ItemId, string? Unit, decimal? RecentCost, decimal? FactorToBase);

        private sealed class IntercompanySalesTransferConnections : IDisposable
        {
            public IntercompanySalesTransferConnections(string targetCode, SqlConnection sourceConnection, SqlConnection targetConnection)
            {
                TargetCode = targetCode;
                SourceConnection = sourceConnection;
                TargetConnection = targetConnection;
            }

            public string TargetCode { get; }

            public SqlConnection SourceConnection { get; }

            public SqlConnection TargetConnection { get; }

            public void Dispose()
            {
                SourceConnection.Dispose();
                TargetConnection.Dispose();
            }
        }
    }
}
