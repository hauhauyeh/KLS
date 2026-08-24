using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Data;

namespace KLS.Services
{
    public class SharedShipmentChargeBillService : BaseService, ISharedShipmentChargeBillService
    {
        private static readonly HashSet<string> ChargeTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            "Freight",
            "CustomDuty",
            "Tariff",
            "Tax",
            "Brokerage",
            "PortCharges",
            "Insurance",
            "ImportCommission",
            "Other"
        };

        private static readonly HashSet<string> SplitMethods = new(StringComparer.OrdinalIgnoreCase)
        {
            "Equal",
            "Percentage",
            "ManualAmount"
        };

        public SharedShipmentChargeBillService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<SharedShipmentChargeBillListDto> GetList()
        {
            var headers = Uow.SharedShipmentChargeBills
                .GetAll()
                .OrderByDescending(b => b.CreatedAt)
                .ThenByDescending(b => b.SharedShipmentChargeBillId)
                .ToList();

            return MapList(headers);
        }

        public SharedShipmentChargeBillDto? GetById(int sharedShipmentChargeBillId)
        {
            var header = Uow.SharedShipmentChargeBills
                .Find(b => b.SharedShipmentChargeBillId == sharedShipmentChargeBillId)
                .FirstOrDefault();

            if (header == null)
                return null;

            var line = Uow.SharedShipmentChargeBillLines
                .Find(l => l.SharedShipmentChargeBillId == sharedShipmentChargeBillId)
                .OrderBy(l => l.SharedShipmentChargeBillLineId)
                .FirstOrDefault();

            var splits = Uow.SharedShipmentChargeBillSplits
                .Find(s => s.SharedShipmentChargeBillId == sharedShipmentChargeBillId)
                .OrderBy(s => s.SharedShipmentChargeBillSplitId)
                .ToList();

            return MapDetail(header, line, splits);
        }

        public SharedShipmentChargeBillDto SaveDraft(SharedShipmentChargeBillSaveReq req)
        {
            if (req == null) throw new ArgumentException("Request is required.");
            EnsureVendorExists(req.VendorPayeeId);

            var line = NormalizeLine(req.Line);
            var splits = NormalizeSplits(req.Splits);
            var vendorDocNumber = NormalizeOptionalText(req.VendorDocNumber, 100, "Vendor document number");

            EnsureUniqueSharedVendorDoc(req.SharedShipmentChargeBillId, req.VendorPayeeId, vendorDocNumber);
            EnsureShipmentsExist(splits.Select(s => s.ShipmentId));

            var isNew = req.SharedShipmentChargeBillId == 0;
            SharedShipmentChargeBill? header = null;

            if (!isNew)
            {
                header = Uow.SharedShipmentChargeBills
                    .Find(b => b.SharedShipmentChargeBillId == req.SharedShipmentChargeBillId)
                    .FirstOrDefault() ?? throw new KeyNotFoundException("Shared charge bill not found.");

                EnsureDraft(header);
            }

            Uow.ExecuteInTransaction(() =>
            {
                if (isNew)
                {
                    header = new SharedShipmentChargeBill
                    {
                        VendorPayeeId = req.VendorPayeeId,
                        VendorDocNumber = vendorDocNumber,
                        BillDate = req.BillDate,
                        Notes = NormalizeOptionalText(req.Notes, 500, "Notes")
                    };

                    Uow.SharedShipmentChargeBills.Add(header);
                    Uow.Commit();
                }
                else
                {
                    header!.VendorPayeeId = req.VendorPayeeId;
                    header.VendorDocNumber = vendorDocNumber;
                    header.BillDate = req.BillDate;
                    header.Notes = NormalizeOptionalText(req.Notes, 500, "Notes");
                    header.UpdatedAt = DateTime.UtcNow;

                    Uow.SharedShipmentChargeBills.Update(header);
                    Uow.SharedShipmentChargeBillLines
                        .Find(l => l.SharedShipmentChargeBillId == header.SharedShipmentChargeBillId)
                        .ExecuteDelete();
                    Uow.SharedShipmentChargeBillSplits
                        .Find(s => s.SharedShipmentChargeBillId == header.SharedShipmentChargeBillId)
                        .ExecuteDelete();
                    Uow.Commit();
                }

                Uow.SharedShipmentChargeBillLines.Add(new SharedShipmentChargeBillLine
                {
                    SharedShipmentChargeBillId = header!.SharedShipmentChargeBillId,
                    ChargeType = line.ChargeType,
                    ChargeAmount = line.ChargeAmount,
                    Notes = NormalizeOptionalText(line.Notes, 500, "Line notes")
                });

                Uow.SharedShipmentChargeBillSplits.AddRange(splits.Select(split => new SharedShipmentChargeBillSplit
                {
                    SharedShipmentChargeBillId = header.SharedShipmentChargeBillId,
                    ShipmentId = split.ShipmentId,
                    SplitMethod = split.SplitMethod,
                    SplitPercent = split.SplitPercent,
                    SplitAmount = split.SplitAmount,
                    GeneratedVendorDocNumber = split.GeneratedVendorDocNumber,
                    Notes = NormalizeOptionalText(split.Notes, 500, "Split notes")
                }));

                Uow.Commit();
            });

            return GetById(header!.SharedShipmentChargeBillId)!;
        }

        public void DeleteDraft(int sharedShipmentChargeBillId)
        {
            var header = Uow.SharedShipmentChargeBills
                .Find(b => b.SharedShipmentChargeBillId == sharedShipmentChargeBillId)
                .FirstOrDefault() ?? throw new KeyNotFoundException("Shared charge bill not found.");

            EnsureDraft(header);

            Uow.ExecuteInTransaction(() =>
            {
                Uow.SharedShipmentChargeBillSplits
                    .Find(s => s.SharedShipmentChargeBillId == sharedShipmentChargeBillId)
                    .ExecuteDelete();
                Uow.SharedShipmentChargeBillLines
                    .Find(l => l.SharedShipmentChargeBillId == sharedShipmentChargeBillId)
                    .ExecuteDelete();
                Uow.SharedShipmentChargeBills.Remove(header);
                Uow.Commit();
            });
        }

        public SharedShipmentChargeBillActionResult Apply(int sharedShipmentChargeBillId)
        {
            return RunSqlAction(() => Uow.SharedShipmentChargeBills.Apply(sharedShipmentChargeBillId));
        }

        public SharedShipmentChargeBillActionResult Void(int sharedShipmentChargeBillId)
        {
            return RunSqlAction(() => Uow.SharedShipmentChargeBills.Void(sharedShipmentChargeBillId));
        }

        private static SharedShipmentChargeBillActionResult RunSqlAction(Func<SharedShipmentChargeBillActionResult> action)
        {
            try
            {
                return action();
            }
            catch (SqlException ex) when (ex.Number >= 50300 && ex.Number < 50500)
            {
                throw new InvalidOperationException(ex.Message, ex);
            }
        }

        private List<SharedShipmentChargeBillListDto> MapList(List<SharedShipmentChargeBill> headers)
        {
            if (headers.Count == 0)
                return [];

            var ids = headers.Select(h => h.SharedShipmentChargeBillId).ToList();
            var vendorIds = headers.Select(h => h.VendorPayeeId).Distinct().ToList();

            var vendorNameById = Uow.Payees
                .Find(p => vendorIds.Contains(p.PayeeId))
                .ToDictionary(p => p.PayeeId, p => p.PayeeName);

            var lines = Uow.SharedShipmentChargeBillLines
                .Find(l => ids.Contains(l.SharedShipmentChargeBillId))
                .ToList();

            var splits = Uow.SharedShipmentChargeBillSplits
                .Find(s => ids.Contains(s.SharedShipmentChargeBillId))
                .ToList();

            var splitIds = splits.Select(s => s.SharedShipmentChargeBillSplitId).ToList();
            var generatedChildren = Uow.ShipmentChargeBills
                .Find(b => b.SourceSharedShipmentChargeBillSplitId.HasValue
                        && splitIds.Contains(b.SourceSharedShipmentChargeBillSplitId.Value))
                .Select(b => new
                {
                    b.ShipmentChargeBillId,
                    b.SourceSharedShipmentChargeBillSplitId
                })
                .ToList();

            return headers.Select(header =>
            {
                var line = lines.FirstOrDefault(l => l.SharedShipmentChargeBillId == header.SharedShipmentChargeBillId);
                var headerSplits = splits.Where(s => s.SharedShipmentChargeBillId == header.SharedShipmentChargeBillId).ToList();
                var headerSplitIds = headerSplits.Select(s => s.SharedShipmentChargeBillSplitId).ToHashSet();

                return new SharedShipmentChargeBillListDto
                {
                    SharedShipmentChargeBillId = header.SharedShipmentChargeBillId,
                    VendorPayeeId = header.VendorPayeeId,
                    VendorName = vendorNameById.TryGetValue(header.VendorPayeeId, out var vendorName) ? vendorName : null,
                    VendorDocNumber = header.VendorDocNumber,
                    BillDate = header.BillDate,
                    Status = header.Status,
                    ChargeType = line?.ChargeType,
                    SourceAmount = line?.ChargeAmount ?? 0m,
                    SplitCount = headerSplits.Count,
                    AppliedChildCount = generatedChildren.Count(c => c.SourceSharedShipmentChargeBillSplitId.HasValue
                        && headerSplitIds.Contains(c.SourceSharedShipmentChargeBillSplitId.Value)),
                    IsReadOnly = !IsDraft(header),
                    CanApply = GetApplyBlockReason(header, line, headerSplits) == null,
                    ReadOnlyReason = IsDraft(header) ? null : "Applied and void shared charge bills are read-only.",
                    CreatedAt = header.CreatedAt,
                    UpdatedAt = header.UpdatedAt
                };
            }).ToList();
        }

        private SharedShipmentChargeBillDto MapDetail(
            SharedShipmentChargeBill header,
            SharedShipmentChargeBillLine? line,
            List<SharedShipmentChargeBillSplit> splits)
        {
            var listRow = MapList([header]).First();
            var shipmentIds = splits.Select(s => s.ShipmentId).Distinct().ToList();
            var shipmentNameById = shipmentIds.Count == 0
                ? new Dictionary<int, string?>()
                : Uow.Shipments
                    .Find(s => shipmentIds.Contains(s.ShipmentId))
                    .ToDictionary(s => s.ShipmentId, s => !string.IsNullOrWhiteSpace(s.DocumentNo) ? s.DocumentNo : s.ContainerNo);

            var splitIds = splits.Select(s => s.SharedShipmentChargeBillSplitId).ToList();
            var generatedChildIdBySplitId = Uow.ShipmentChargeBills
                .Find(b => b.SourceSharedShipmentChargeBillSplitId.HasValue
                        && splitIds.Contains(b.SourceSharedShipmentChargeBillSplitId.Value))
                .ToDictionary(b => b.SourceSharedShipmentChargeBillSplitId!.Value, b => b.ShipmentChargeBillId);

            return new SharedShipmentChargeBillDto
            {
                SharedShipmentChargeBillId = listRow.SharedShipmentChargeBillId,
                VendorPayeeId = listRow.VendorPayeeId,
                VendorName = listRow.VendorName,
                VendorDocNumber = listRow.VendorDocNumber,
                BillDate = listRow.BillDate,
                Status = listRow.Status,
                ChargeType = listRow.ChargeType,
                SourceAmount = listRow.SourceAmount,
                SplitCount = listRow.SplitCount,
                AppliedChildCount = listRow.AppliedChildCount,
                IsReadOnly = listRow.IsReadOnly,
                CanApply = listRow.CanApply,
                ReadOnlyReason = listRow.ReadOnlyReason,
                CreatedAt = listRow.CreatedAt,
                UpdatedAt = listRow.UpdatedAt,
                Notes = header.Notes,
                Line = line == null ? null : new SharedShipmentChargeBillLineDto
                {
                    SharedShipmentChargeBillLineId = line.SharedShipmentChargeBillLineId,
                    SharedShipmentChargeBillId = line.SharedShipmentChargeBillId,
                    ChargeType = line.ChargeType,
                    ChargeAmount = line.ChargeAmount,
                    Notes = line.Notes
                },
                Splits = splits.Select(split => new SharedShipmentChargeBillSplitDto
                {
                    SharedShipmentChargeBillSplitId = split.SharedShipmentChargeBillSplitId,
                    SharedShipmentChargeBillId = split.SharedShipmentChargeBillId,
                    ShipmentId = split.ShipmentId,
                    ShipmentNumber = shipmentNameById.TryGetValue(split.ShipmentId, out var shipmentNumber) ? shipmentNumber : null,
                    SplitMethod = split.SplitMethod,
                    SplitPercent = split.SplitPercent,
                    SplitAmount = split.SplitAmount,
                    GeneratedVendorDocNumber = split.GeneratedVendorDocNumber,
                    GeneratedShipmentChargeBillId = generatedChildIdBySplitId.TryGetValue(split.SharedShipmentChargeBillSplitId, out var generatedChildId)
                        ? generatedChildId
                        : null,
                    Notes = split.Notes
                }).ToList()
            };
        }

        private SharedShipmentChargeBillLineReq NormalizeLine(SharedShipmentChargeBillLineReq? line)
        {
            if (line == null)
                throw new ArgumentException("One charge line is required.");

            var chargeType = (line.ChargeType ?? string.Empty).Trim();
            if (!ChargeTypes.TryGetValue(chargeType, out var canonicalType))
                throw new ArgumentException($"Charge type '{line.ChargeType}' is not supported.");

            if (line.ChargeAmount < 0m)
                throw new ArgumentException("Charge amount cannot be negative.");

            return new SharedShipmentChargeBillLineReq
            {
                SharedShipmentChargeBillLineId = line.SharedShipmentChargeBillLineId,
                ChargeType = canonicalType,
                ChargeAmount = line.ChargeAmount,
                Notes = line.Notes
            };
        }

        private List<SharedShipmentChargeBillSplitReq> NormalizeSplits(IEnumerable<SharedShipmentChargeBillSplitReq>? splits)
        {
            var normalized = new List<SharedShipmentChargeBillSplitReq>();
            var shipmentIds = new HashSet<int>();

            foreach (var split in splits ?? [])
            {
                if (split.ShipmentId <= 0)
                    throw new ArgumentException("Shipment is required for every split.");

                if (!shipmentIds.Add(split.ShipmentId))
                    throw new ArgumentException("Each target shipment can appear only once.");

                var splitMethod = (split.SplitMethod ?? string.Empty).Trim();
                if (!SplitMethods.TryGetValue(splitMethod, out var canonicalMethod))
                    throw new ArgumentException($"Split method '{split.SplitMethod}' is not supported.");

                if (split.SplitPercent.HasValue && (split.SplitPercent.Value < 0m || split.SplitPercent.Value > 100m))
                    throw new ArgumentException("Split percent must be between 0 and 100.");

                if (split.SplitAmount < 0m)
                    throw new ArgumentException("Split amount cannot be negative.");

                normalized.Add(new SharedShipmentChargeBillSplitReq
                {
                    SharedShipmentChargeBillSplitId = split.SharedShipmentChargeBillSplitId,
                    ShipmentId = split.ShipmentId,
                    SplitMethod = canonicalMethod,
                    SplitPercent = split.SplitPercent,
                    SplitAmount = split.SplitAmount,
                    GeneratedVendorDocNumber = NormalizeOptionalText(split.GeneratedVendorDocNumber, 100, "Generated vendor document number"),
                    Notes = split.Notes
                });
            }

            return normalized;
        }

        private void EnsureVendorExists(int vendorPayeeId)
        {
            if (!Uow.Payees.Exists(p => p.PayeeId == vendorPayeeId))
                throw new ArgumentException("Vendor payee not found.");
        }

        private void EnsureShipmentsExist(IEnumerable<int> shipmentIds)
        {
            foreach (var shipmentId in shipmentIds.Distinct())
            {
                if (!Uow.Shipments.Exists(s => s.ShipmentId == shipmentId))
                    throw new ArgumentException($"Shipment {shipmentId} not found.");
            }
        }

        private void EnsureUniqueSharedVendorDoc(int currentId, int vendorPayeeId, string? vendorDocNumber)
        {
            if (vendorDocNumber == null)
                return;

            var existingDocs = Uow.SharedShipmentChargeBills
                .Find(b => b.SharedShipmentChargeBillId != currentId
                        && b.VendorPayeeId == vendorPayeeId
                        && b.Status != "Void"
                        && b.VendorDocNumber != null)
                .Select(b => b.VendorDocNumber)
                .ToList();

            var duplicate = existingDocs.Any(doc =>
                string.Equals(doc?.Trim(), vendorDocNumber, StringComparison.OrdinalIgnoreCase));

            if (duplicate)
                throw new DuplicateNameException("Vendor document number already exists for this vendor.");
        }

        private static void EnsureDraft(SharedShipmentChargeBill header)
        {
            if (!IsDraft(header))
                throw new InvalidOperationException("Only Draft shared charge bills can be edited.");
        }

        private static bool IsDraft(SharedShipmentChargeBill header)
        {
            return string.Equals(header.Status, "Draft", StringComparison.OrdinalIgnoreCase);
        }

        private static string? GetApplyBlockReason(
            SharedShipmentChargeBill header,
            SharedShipmentChargeBillLine? line,
            List<SharedShipmentChargeBillSplit> splits)
        {
            if (!IsDraft(header))
                return "Only Draft shared charge bills can be applied.";

            if (line == null)
                return "One charge line is required.";

            if (splits.Count == 0)
                return "Add at least one shipment split.";

            if (splits.Any(s => s.SplitAmount <= 0m))
                return "Every applied split amount must be positive.";

            if (splits.Any(s => string.IsNullOrWhiteSpace(s.GeneratedVendorDocNumber)))
                return "Generated vendor document number is required for every split.";

            if (Math.Abs(splits.Sum(s => s.SplitAmount) - line.ChargeAmount) > 0.01m)
                return "Split total must match the source amount.";

            return null;
        }

        private static string? NormalizeOptionalText(string? value, int maxLength, string fieldName)
        {
            var text = value?.Trim();
            if (string.IsNullOrWhiteSpace(text))
                return null;

            if (text.Length > maxLength)
                throw new ArgumentException($"{fieldName} cannot exceed {maxLength} characters.");

            return text;
        }
    }
}
