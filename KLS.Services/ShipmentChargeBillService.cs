using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;

namespace KLS.Services
{
    public class ShipmentChargeBillService : BaseService, IShipmentChargeBillService
    {
        private readonly IShipmentService _shipmentService;

        private static readonly Dictionary<string, string> ChargeTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            ["Freight"] = "Freight",
            ["CustomDuty"] = "CustomDuty",
            ["Tariff"] = "Tariff",
            ["Tax"] = "Tax",
            ["Brokerage"] = "Brokerage",
            ["PortCharges"] = "PortCharges",
            ["Insurance"] = "Insurance",
            ["ImportCommission"] = "ImportCommission",
            ["Other"] = "Other"
        };

        public ShipmentChargeBillService(IUnitOfWork uow, IShipmentService shipmentService) : base(uow)
        {
            _shipmentService = shipmentService;
        }

        public IEnumerable<ShipmentChargeBillDto> GetByShipmentId(int shipmentId)
        {
            EnsureShipmentExists(shipmentId);

            var bills = Uow.ShipmentChargeBills
                .Find(b => b.ShipmentId == shipmentId)
                .OrderBy(b => b.BillDate)
                .ThenBy(b => b.ShipmentChargeBillId)
                .ToList();

            return MapDtos(bills, includeLines: false);
        }

        public ShipmentChargeBillDto? GetById(int shipmentChargeBillId)
        {
            var bill = Uow.ShipmentChargeBills
                .Find(b => b.ShipmentChargeBillId == shipmentChargeBillId)
                .FirstOrDefault();

            if (bill == null)
                return null;

            return MapDtos([bill], includeLines: true).First();
        }

        public ShipmentChargeBillDto Save(ShipmentChargeBillSaveReq req)
        {
            if (req == null) throw new ArgumentException("Request is required.");

            EnsureShipmentExists(req.ShipmentId);
            EnsureVendorExists(req.VendorPayeeId);

            var normalizedLines = NormalizeLines(req.Lines);
            if (normalizedLines.Count == 0)
                throw new ArgumentException("Add at least one charge line.");

            var isNew = req.ShipmentChargeBillId == 0;
            ShipmentChargeBill? bill = null;

            if (!isNew)
            {
                bill = Uow.ShipmentChargeBills
                    .Find(b => b.ShipmentChargeBillId == req.ShipmentChargeBillId)
                    .FirstOrDefault() ?? throw new KeyNotFoundException("Charge bill not found.");

                if (bill.ShipmentId != req.ShipmentId)
                    throw new ArgumentException("Charge bill does not belong to this shipment.");

                EnsureLinkedBillIsEditable(bill.PurchaseId, "Charge bill cannot be edited because its generated AP bill is paid or locked.");
            }

            var isFirstBill = isNew && !Uow.ShipmentChargeBills.Exists(b => b.ShipmentId == req.ShipmentId);
            var legacySourceCharges = isFirstBill
                ? GetLegacySourceCharges(req.ShipmentId)
                : new List<ShipmentCharge>();

            if (legacySourceCharges.Count > 0)
            {
                if (!req.ConvertLegacyCharges)
                    throw new InvalidOperationException("This shipment has legacy charges. Confirm conversion before adding charge bills.");

                EnsureShipmentOpenForConversion(req.ShipmentId);
                EnsureLegacyTotalsMatch(legacySourceCharges, normalizedLines);
            }

            EnsureSplitTotalsRemainMatched(req.ShipmentId, req.ShipmentChargeBillId, normalizedLines, "saving");

            Uow.ExecuteInTransaction(() =>
            {
                var legacyChargesToConvert = legacySourceCharges.Count > 0
                    ? GetLegacySourceCharges(req.ShipmentId)
                    : new List<ShipmentCharge>();

                if (legacyChargesToConvert.Count > 0)
                    EnsureLegacyTotalsMatch(legacyChargesToConvert, normalizedLines);

                if (isNew)
                {
                    bill = new ShipmentChargeBill
                    {
                        ShipmentId = req.ShipmentId,
                        VendorPayeeId = req.VendorPayeeId,
                        VendorDocNumber = NormalizeText(req.VendorDocNumber),
                        BillDate = req.BillDate,
                        Notes = NormalizeText(req.Notes)
                    };

                    Uow.ShipmentChargeBills.Add(bill);
                    Uow.Commit();
                }
                else
                {
                    bill!.VendorPayeeId = req.VendorPayeeId;
                    bill.VendorDocNumber = NormalizeText(req.VendorDocNumber);
                    bill.BillDate = req.BillDate;
                    bill.Notes = NormalizeText(req.Notes);
                    bill.UpdatedAt = DateTime.UtcNow;

                    Uow.ShipmentChargeBills.Update(bill);
                    Uow.ShipmentChargeBillLines
                        .Find(l => l.ShipmentChargeBillId == bill.ShipmentChargeBillId)
                        .ExecuteDelete();
                    Uow.Commit();
                }

                var lines = normalizedLines.Select(line => new ShipmentChargeBillLine
                {
                    ShipmentChargeBillId = bill!.ShipmentChargeBillId,
                    ChargeType = line.ChargeType,
                    ChargeAmount = line.ChargeAmount,
                    Notes = NormalizeText(line.Notes)
                }).ToList();

                Uow.ShipmentChargeBillLines.AddRange(lines);
                Uow.Commit();

                if (legacyChargesToConvert.Count > 0)
                {
                    foreach (var charge in legacyChargesToConvert)
                    {
                        Uow.ShipmentCharges.Remove(charge);
                    }

                    Uow.Commit();
                }

                Uow.Shipments.RebuildChargesFromChargeBills(req.ShipmentId);
            });

            return GetById(bill!.ShipmentChargeBillId)!;
        }

        public void Delete(int shipmentChargeBillId)
        {
            var bill = Uow.ShipmentChargeBills
                .Find(b => b.ShipmentChargeBillId == shipmentChargeBillId)
                .FirstOrDefault() ?? throw new KeyNotFoundException("Charge bill not found.");

            if (bill.PurchaseId.HasValue)
                throw new InvalidOperationException("Billed charge bills cannot be deleted.");

            EnsureSplitTotalsRemainMatched(bill.ShipmentId, bill.ShipmentChargeBillId, [], "deleting");

            Uow.ExecuteInTransaction(() =>
            {
                Uow.ShipmentChargeBillLines
                    .Find(l => l.ShipmentChargeBillId == shipmentChargeBillId)
                    .ExecuteDelete();

                Uow.ShipmentChargeBills.Remove(bill);
                Uow.Commit();

                if (Uow.ShipmentChargeBills.Exists(b => b.ShipmentId == bill.ShipmentId))
                {
                    Uow.Shipments.RebuildChargesFromChargeBills(bill.ShipmentId);
                }
                else
                {
                    Uow.ShipmentCharges
                        .Find(c => c.ShipmentId == bill.ShipmentId
                                && c.ShipmentPurchaseId == null
                                && c.IsGeneratedFromChargeBills)
                        .ExecuteDelete();

                    Uow.Shipments.RefreshSingleBillAllocation(bill.ShipmentId);
                }
            });
        }

        public IEnumerable<ShipmentChargeBillDto> Generate(int shipmentId)
        {
            EnsureShipmentExists(shipmentId);
            EnsureCanGenerate(shipmentId);

            _shipmentService.GenerateBill(shipmentId);

            return GetByShipmentId(shipmentId);
        }

        private void EnsureShipmentExists(int shipmentId)
        {
            if (!Uow.Shipments.Exists(s => s.ShipmentId == shipmentId))
                throw new KeyNotFoundException("Shipment not found.");
        }

        private void EnsureVendorExists(int vendorPayeeId)
        {
            if (!Uow.Payees.Exists(p => p.PayeeId == vendorPayeeId))
                throw new ArgumentException("Vendor payee not found.");
        }

        private void EnsureNoLegacySourceCharges(int shipmentId)
        {
            var hasLegacy = Uow.ShipmentCharges
                .Find(c => c.ShipmentId == shipmentId
                        && c.ShipmentPurchaseId == null
                        && !c.IsGeneratedFromChargeBills
                        && (c.ChargeAmount ?? 0m) != 0m)
                .Any();

            if (hasLegacy)
                throw new InvalidOperationException("This shipment has legacy charges. Convert them before adding charge bills.");
        }

        private List<ShipmentCharge> GetLegacySourceCharges(int shipmentId)
        {
            return Uow.ShipmentCharges
                .Find(c => c.ShipmentId == shipmentId
                        && c.ShipmentPurchaseId == null
                        && !c.IsGeneratedFromChargeBills
                        && (c.ChargeAmount ?? 0m) != 0m)
                .ToList();
        }

        private void EnsureShipmentOpenForConversion(int shipmentId)
        {
            var shipment = Uow.Shipments
                .Find(s => s.ShipmentId == shipmentId)
                .FirstOrDefault() ?? throw new KeyNotFoundException("Shipment not found.");

            if (string.Equals(shipment.Status, "Closed", StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Closed shipment can not be converted to charge bills.");
        }

        private static void EnsureLegacyTotalsMatch(List<ShipmentCharge> legacyCharges, List<ShipmentChargeBillLineReq> lines)
        {
            var legacyTotals = legacyCharges
                .GroupBy(c => c.ChargeType ?? string.Empty, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(g => g.Key, g => g.Sum(c => c.ChargeAmount ?? 0m), StringComparer.OrdinalIgnoreCase);

            var lineTotals = lines
                .GroupBy(l => l.ChargeType, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(g => g.Key, g => g.Sum(l => l.ChargeAmount), StringComparer.OrdinalIgnoreCase);

            var chargeTypes = legacyTotals.Keys
                .Union(lineTotals.Keys, StringComparer.OrdinalIgnoreCase);

            foreach (var chargeType in chargeTypes)
            {
                legacyTotals.TryGetValue(chargeType, out var legacyTotal);
                lineTotals.TryGetValue(chargeType, out var lineTotal);

                if (Math.Abs(legacyTotal - lineTotal) > 0.01m)
                    throw new InvalidOperationException("Charge bill conversion total must match saved legacy charges.");
            }
        }

        private void EnsureSplitTotalsRemainMatched(
            int shipmentId,
            int replacingShipmentChargeBillId,
            List<ShipmentChargeBillLineReq> replacementLines,
            string action)
        {
            var splitTotals = Uow.ShipmentCharges
                .Find(c => c.ShipmentId == shipmentId
                        && c.ShipmentPurchaseId != null
                        && (c.ChargeAmount ?? 0m) != 0m)
                .ToList()
                .GroupBy(c => c.ChargeType ?? string.Empty, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(g => g.Key, g => g.Sum(c => c.ChargeAmount ?? 0m), StringComparer.OrdinalIgnoreCase);

            if (splitTotals.Count == 0)
                return;

            var existingBillIds = Uow.ShipmentChargeBills
                .Find(b => b.ShipmentId == shipmentId
                        && b.ShipmentChargeBillId != replacingShipmentChargeBillId)
                .Select(b => b.ShipmentChargeBillId)
                .ToList();

            var proposedTotals = existingBillIds.Count == 0
                ? new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase)
                : Uow.ShipmentChargeBillLines
                    .Find(l => existingBillIds.Contains(l.ShipmentChargeBillId))
                    .ToList()
                    .GroupBy(l => l.ChargeType, StringComparer.OrdinalIgnoreCase)
                    .ToDictionary(g => g.Key, g => g.Sum(l => l.ChargeAmount), StringComparer.OrdinalIgnoreCase);

            foreach (var lineTotal in replacementLines
                .GroupBy(l => l.ChargeType, StringComparer.OrdinalIgnoreCase)
                .Select(g => new { ChargeType = g.Key, Amount = g.Sum(l => l.ChargeAmount) }))
            {
                proposedTotals.TryGetValue(lineTotal.ChargeType, out var existingTotal);
                proposedTotals[lineTotal.ChargeType] = existingTotal + lineTotal.Amount;
            }

            foreach (var splitTotal in splitTotals)
            {
                proposedTotals.TryGetValue(splitTotal.Key, out var proposedTotal);

                if (Math.Abs(proposedTotal - splitTotal.Value) > 0.01m)
                    throw new InvalidOperationException($"{splitTotal.Key} total changed after split. Re-split {splitTotal.Key} before {action} this charge bill.");
            }
        }

        private void EnsureCanGenerate(int shipmentId)
        {
            var hasBills = Uow.ShipmentChargeBills.Exists(b => b.ShipmentId == shipmentId);
            if (!hasBills)
                throw new ArgumentException("Add at least one charge bill before generating AP bills.");

            var billIds = Uow.ShipmentChargeBills
                .Find(b => b.ShipmentId == shipmentId)
                .Select(b => b.ShipmentChargeBillId)
                .ToList();

            var hasFreight = Uow.ShipmentChargeBillLines
                .Find(l => billIds.Contains(l.ShipmentChargeBillId)
                        && l.ChargeType == "Freight"
                        && l.ChargeAmount > 0m)
                .Any();

            if (!hasFreight)
                throw new ArgumentException("At least one Freight line greater than zero is required before generating AP bills.");
        }

        private void EnsureLinkedBillIsEditable(int? purchaseId, string message)
        {
            if (!purchaseId.HasValue)
                return;

            var isLocked = Uow.Purchases
                .Find(p => p.PurchaseId == purchaseId.Value
                        && p.IsShipment
                        && (p.IsLocked || (p.PaymentApplied ?? 0m) > 0m))
                .Any();

            if (isLocked)
                throw new InvalidOperationException(message);
        }

        private static List<ShipmentChargeBillLineReq> NormalizeLines(IEnumerable<ShipmentChargeBillLineReq>? lines)
        {
            var normalized = new List<ShipmentChargeBillLineReq>();

            foreach (var line in lines ?? [])
            {
                var chargeType = (line.ChargeType ?? string.Empty).Trim();
                if (string.IsNullOrWhiteSpace(chargeType) && line.ChargeAmount == 0m && string.IsNullOrWhiteSpace(line.Notes))
                    continue;

                if (!ChargeTypes.TryGetValue(chargeType, out var canonicalType))
                    throw new ArgumentException($"Charge type '{line.ChargeType}' is not supported.");

                if (line.ChargeAmount < 0m)
                    throw new ArgumentException("Charge amount cannot be negative.");

                normalized.Add(new ShipmentChargeBillLineReq
                {
                    ShipmentChargeBillLineId = line.ShipmentChargeBillLineId,
                    ChargeType = canonicalType,
                    ChargeAmount = line.ChargeAmount,
                    Notes = line.Notes
                });
            }

            return normalized;
        }

        private List<ShipmentChargeBillDto> MapDtos(List<ShipmentChargeBill> bills, bool includeLines)
        {
            if (bills.Count == 0)
                return [];

            var billIds = bills.Select(b => b.ShipmentChargeBillId).ToList();
            var vendorIds = bills.Select(b => b.VendorPayeeId).Distinct().ToList();
            var purchaseIds = bills.Where(b => b.PurchaseId.HasValue).Select(b => b.PurchaseId!.Value).Distinct().ToList();

            var lines = Uow.ShipmentChargeBillLines
                .Find(l => billIds.Contains(l.ShipmentChargeBillId))
                .ToList();

            var vendorNameById = Uow.Payees
                .Find(p => vendorIds.Contains(p.PayeeId))
                .ToDictionary(p => p.PayeeId, p => p.PayeeName);

            var purchaseById = Uow.Purchases
                .Find(p => purchaseIds.Contains(p.PurchaseId))
                .ToDictionary(p => p.PurchaseId);

            return bills.Select(b =>
            {
                var billLines = lines
                    .Where(l => l.ShipmentChargeBillId == b.ShipmentChargeBillId)
                    .OrderBy(l => l.ShipmentChargeBillLineId)
                    .ToList();

                purchaseById.TryGetValue(b.PurchaseId ?? 0, out var purchase);

                return new ShipmentChargeBillDto
                {
                    ShipmentChargeBillId = b.ShipmentChargeBillId,
                    ShipmentId = b.ShipmentId,
                    VendorPayeeId = b.VendorPayeeId,
                    VendorName = vendorNameById.TryGetValue(b.VendorPayeeId, out var name) ? name : null,
                    VendorDocNumber = b.VendorDocNumber,
                    BillDate = b.BillDate,
                    PurchaseId = b.PurchaseId,
                    PurchaseNumber = purchase?.PurchaseNumber,
                    State = b.PurchaseId.HasValue ? "Billed" : "Draft",
                    TotalAmount = billLines.Sum(l => l.ChargeAmount),
                    IsReadOnly = purchase != null && (purchase.IsLocked || (purchase.PaymentApplied ?? 0m) > 0m),
                    Notes = b.Notes,
                    CreatedAt = b.CreatedAt,
                    UpdatedAt = b.UpdatedAt,
                    Lines = includeLines
                        ? billLines.Select(l => new ShipmentChargeBillLineDto
                        {
                            ShipmentChargeBillLineId = l.ShipmentChargeBillLineId,
                            ShipmentChargeBillId = l.ShipmentChargeBillId,
                            ChargeType = l.ChargeType,
                            ChargeAmount = l.ChargeAmount,
                            Notes = l.Notes
                        }).ToList()
                        : []
                };
            }).ToList();
        }

        private static string? NormalizeText(string? value)
        {
            var text = value?.Trim();
            return string.IsNullOrWhiteSpace(text) ? null : text;
        }
    }
}
