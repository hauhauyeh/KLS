using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ShipmentService : BaseService, IShipmentService
    {
        public ShipmentService(IUnitOfWork uow) : base(uow)
        {
        }

        public PagingResponse<ShipmentList> GetPagedList(ShipmentListReq shipmentListReq)
        {
            var list = Uow.Shipments.GetPagedList(shipmentListReq);

            var totalRecords = Uow.Shipments.Count(shipmentListReq);

            return new PagingResponse<ShipmentList>(totalRecords, shipmentListReq.Pageno, shipmentListReq.Pagesize)
            {
                RowData = list,
            };
        }

        public PagingResponse<ShipmentManagerListRow> GetManagerList(ShipmentListReq shipmentListReq)
        {
            var list = Uow.Shipments.GetManagerList(shipmentListReq);

            var totalRecords = Uow.Shipments.CountManagerList(shipmentListReq);

            return new PagingResponse<ShipmentManagerListRow>(totalRecords, shipmentListReq.Pageno, shipmentListReq.Pagesize)
            {
                RowData = list,
            };
        }

        public IEnumerable<ShipmentList> GetOpenShipments()
        {
            return Uow.Shipments.GetPagedList(new ShipmentListReq
            {
                Pagesize = 500,
                Filterby = "open"
            }).ToList();
        }

        public Shipment? GetById(int shipmentId)
        {
            var shipment = Uow.Shipments.Find(c => c.ShipmentId == shipmentId).Include(c => c.Charges).FirstOrDefault();
            if (shipment != null)
                shipment.IsFreightSplitLocked = HasLockedShipmentBill(shipment.ShipmentId);

            return shipment;
        }

        public bool Exists(Shipment shipment)
        {
            // If no identifier is provided, we allow duplicates (can't determine uniqueness)
            var hasContainer = !string.IsNullOrWhiteSpace(shipment.ContainerNo);
            var hasDoc = !string.IsNullOrWhiteSpace(shipment.DocumentNo);

            if (!hasContainer && !hasDoc)
                return false;

            var q = Uow.Shipments.Find(c => c.ShipmentId != shipment.ShipmentId);

            // Check ContainerNo if provided
            if (hasContainer)
            {
                var containerNo = shipment.ContainerNo!.Trim();
                if (q.Any(c => c.ContainerNo != null && c.ContainerNo.Trim() == containerNo))
                    return true;
            }

            // Check DocumentNo if provided
            if (hasDoc)
            {
                var documentNo = shipment.DocumentNo!.Trim();
                if (q.Any(c => c.DocumentNo != null && c.DocumentNo.Trim() == documentNo))
                    return true;
            }

            return false;
        }

        public Shipment Create(Shipment shipment)
        {
            if (shipment == null) throw new ArgumentNullException(nameof(shipment));

            shipment.ShipmentId = 0;
            shipment.ContainerNo = shipment.ContainerNo?.ToUpper();

            if (string.IsNullOrWhiteSpace(shipment.Status))
                shipment.Status = EnumHelper.ShipmentStatus.Draft.ToString(); // if you have Draft

            // Ensure AllocationMethod is set for each charge before saving
            if (shipment.Charges != null)
            {
                foreach (var ch in shipment.Charges)
                {
                    var hasData =
                        !string.IsNullOrWhiteSpace(ch.ChargeType) ||
                        (ch.ChargeAmount.HasValue && ch.ChargeAmount.Value != 0) ||
                        !string.IsNullOrWhiteSpace(ch.Notes);

                    if (!hasData) continue;

                    // Per-bill rows are owned by SplitCharge; never restamp them here.
                    if (ch.ShipmentPurchaseId != null) continue;

                    ch.AllocationMethod = GetAllocationMethodFromChargeType(ch.ChargeType);
                }
            }

            Uow.Shipments.Add(shipment);
            Uow.Commit();

            return shipment;
        }

        public Shipment Update(Shipment shipment)
        {
            var existing = GetById(shipment.ShipmentId);

            if (existing == null) throw new KeyNotFoundException("Shipment not found.");

            // Block edits once arrived (same rule as Delete)
            if (existing.Status == EnumHelper.ShipmentStatus.Closed.ToString())
                throw new InvalidOperationException("Closed shipment can not be updated.");

            existing.ShipmentType = shipment.ShipmentType;
            existing.ContainerNo = shipment.ContainerNo?.ToUpper();
            existing.ContainerType = shipment.ContainerType;
            existing.PayeeId = shipment.PayeeId;
            existing.DocumentNo = shipment.DocumentNo;
            existing.Origin = shipment.Origin;
            existing.Destination = shipment.Destination;
            existing.ETD = shipment.ETD;
            existing.ETA = shipment.ETA;
            existing.Status = shipment.Status;
            existing.DutyStatus = shipment.DutyStatus;
            existing.Notes = shipment.Notes;
            existing.UpdatedAt = DateTime.UtcNow;

            // Save
            Uow.Shipments.Update(existing);
            Uow.Commit();

            // --- sync (add / update) ---
            var existingCharges = Uow.ShipmentCharges
                .Find(c => c.ShipmentId == shipment.ShipmentId)
                .ToList();

            var incomingCharges = shipment.Charges ?? [];

            if (Uow.Shipments.HasChargeBills(shipment.ShipmentId))
            {
                if (HasLegacyChargeChanges(existingCharges, incomingCharges))
                    throw new InvalidOperationException("Shipment charges are managed by charge bills and cannot be edited here.");

                return existing;
            }

            // 1) DELETE removed charges (exists in DB but not coming from UI)
            var incomingIds = incomingCharges
                .Select(x => x.ChargeId)
                .ToHashSet();

            // Per-bill redesign: the legacy charge-sync owns ONLY legacy shipment-wide charges
            // (ShipmentPurchaseId == null). Per-bill charges are managed exclusively by SplitCharge -
            // never delete or restamp them here.
            Uow.ShipmentCharges
                .Find(x => x.ShipmentId == shipment.ShipmentId
                        && x.ShipmentPurchaseId == null
                        && !incomingIds.Contains(x.ChargeId))
                .ExecuteDelete();

            // 2) ADD / UPDATE
            foreach (var ch in incomingCharges)
            {
                // ignore empty rows (optional, but good)
                var hasData =
                    !string.IsNullOrWhiteSpace(ch.ChargeType) ||
                    (ch.ChargeAmount.HasValue && ch.ChargeAmount.Value != 0) ||
                    !string.IsNullOrWhiteSpace(ch.Notes);

                if (!hasData) continue;

                // Never let the legacy sync create or touch per-bill rows (owned by SplitCharge).
                if (ch.ShipmentPurchaseId != null) continue;

                if (ch.ChargeId == 0)
                {
                    // NEW CHARGE: add
                    ch.ShipmentId = shipment.ShipmentId;

                    ch.AllocationMethod = GetAllocationMethodFromChargeType(ch.ChargeType);

                    Uow.ShipmentCharges.Add(ch);
                }
                else
                {
                    // EXISTING CHARGE: update
                    var dbCharge = existingCharges.FirstOrDefault(x => x.ChargeId == ch.ChargeId);

                    if (dbCharge != null)
                    {
                        dbCharge.ChargeType = ch.ChargeType;
                        dbCharge.ChargeAmount = ch.ChargeAmount;
                        dbCharge.Notes = ch.Notes;
                        dbCharge.UpdatedAt = DateTime.UtcNow;

                        dbCharge.AllocationMethod = GetAllocationMethodFromChargeType(ch.ChargeType);

                        Uow.ShipmentCharges.Update(dbCharge);
                    }
                }
            }

            Uow.Commit();

            Uow.Shipments.ResetCompletionAndReallocate(shipment.ShipmentId);

            return existing;
        }

        private static bool HasLegacyChargeChanges(List<ShipmentCharge> existingCharges, IEnumerable<ShipmentCharge> incomingCharges)
        {
            var incomingLegacy = incomingCharges
                .Where(HasChargeData)
                .Where(c => c.ShipmentPurchaseId == null)
                .ToList();

            // Some header-only saves may post no charges. In charge-bill mode that is not an edit.
            if (incomingLegacy.Count == 0)
                return false;

            if (incomingLegacy.Any(c => c.ChargeId == 0))
                return true;

            var existingLegacy = existingCharges
                .Where(c => c.ShipmentPurchaseId == null)
                .ToDictionary(c => c.ChargeId);

            var incomingIds = incomingLegacy
                .Select(c => c.ChargeId)
                .ToHashSet();

            if (existingLegacy.Keys.Any(id => !incomingIds.Contains(id)))
                return true;

            foreach (var incoming in incomingLegacy)
            {
                if (!existingLegacy.TryGetValue(incoming.ChargeId, out var existing))
                    return true;

                if (!SameChargeValue(existing, incoming))
                    return true;
            }

            return false;
        }

        private static bool HasChargeData(ShipmentCharge ch)
        {
            return !string.IsNullOrWhiteSpace(ch.ChargeType)
                || (ch.ChargeAmount.HasValue && ch.ChargeAmount.Value != 0)
                || !string.IsNullOrWhiteSpace(ch.Notes);
        }

        private static bool SameChargeValue(ShipmentCharge left, ShipmentCharge right)
        {
            return string.Equals((left.ChargeType ?? "").Trim(), (right.ChargeType ?? "").Trim(), StringComparison.OrdinalIgnoreCase)
                && (left.ChargeAmount ?? 0m) == (right.ChargeAmount ?? 0m)
                && string.Equals(left.Notes ?? "", right.Notes ?? "", StringComparison.Ordinal);
        }

        public void UpdateNotes(Shipment shipment)
        {
            Uow.Shipments.Find(c => c.ShipmentId == shipment.ShipmentId).ExecuteUpdate(setters => setters
           .SetProperty(x => x.Notes, x => shipment.Notes)
           .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public void UpdateTracking(int shipmentId, ShipmentTrackingUpdateReq req)
        {
            if (req == null) throw new ArgumentException("Request is required.");

            var shipment = Uow.Shipments.Find(s => s.ShipmentId == shipmentId).FirstOrDefault();
            if (shipment == null) throw new KeyNotFoundException("Shipment not found.");

            if (shipment.Status == EnumHelper.ShipmentStatus.Closed.ToString())
                throw new InvalidOperationException("Closed shipment can not be updated.");

            Uow.Shipments.Find(c => c.ShipmentId == shipmentId).ExecuteUpdate(setters => setters
                .SetProperty(x => x.ETD, x => req.ETD)
                .SetProperty(x => x.ETA, x => req.ETA)
                .SetProperty(x => x.DutyStatus, x => req.DutyStatus)
                .SetProperty(x => x.Notes, x => req.Notes)
                .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public void Delete(int shipmentId)
        {
            Uow.Shipments.Delete(shipmentId);
        }

        public Shipment? Reopen(int shipmentId)
        {
            var shipment = GetById(shipmentId);

            if (shipment != null && shipment.Status == EnumHelper.ShipmentStatus.Closed.ToString())
            {
                shipment.Status = EnumHelper.ShipmentStatus.Allocated.ToString();
                shipment.UpdatedAt = DateTime.UtcNow;

                Uow.Shipments.Update(shipment);
                Uow.Commit();
            }

            return shipment;
        }

        public Shipment? GenerateBill(int shipmentId)
        {
            // Backward-compatible endpoint wrapper. Final AP charge-bill generation
            // belongs to the explicit confirmation operation.
            ConfirmChargesComplete(shipmentId);

            return GetById(shipmentId);
        }

        public ShipmentConfirmChargesCompleteResult ConfirmChargesComplete(int shipmentId)
        {
            if (!Uow.Shipments.Exists(s => s.ShipmentId == shipmentId))
                throw new KeyNotFoundException("Shipment not found.");

            if (UserContext.EmpId <= 0)
                throw new UnauthorizedAccessException("Employee context is required.");

            return Uow.Shipments.ConfirmChargesComplete(shipmentId, UserContext.EmpId);
        }

        public void UnAllocation(int shipmentPurchaseId)
        {
            Uow.Shipments.UnAllocation(shipmentPurchaseId);
        }

        public int UnassignPurchases(int shipmentId, ShipmentUnassignPurchasesReq req)
        {
            if (req?.ShipmentPurchaseIds == null || req.ShipmentPurchaseIds.Count == 0)
                throw new ArgumentException("No source bills selected.");

            if (req.ShipmentPurchaseIds.Any(id => id <= 0))
                throw new ArgumentException("One or more selected source bill ids are invalid.");

            var ids = req.ShipmentPurchaseIds
                .Distinct()
                .ToList();

            Uow.Shipments.UnassignPurchases(shipmentId, string.Join(",", ids));

            return ids.Count;
        }

        public IEnumerable<AssignedPurchase>? AssignedPurchases(int shipmentId)
        {
            return Uow.Shipments.AssignedPurchases(shipmentId);
        }

        public IEnumerable<BillBasisUsability>? BillBasisUsability(int shipmentId)
        {
            return Uow.Shipments.BillBasisUsability(shipmentId);
        }

        public IEnumerable<EligibleBill>? EligibleBills(int shipmentId, string? search)
        {
            return Uow.Shipments.EligibleBills(shipmentId, search);
        }

        public int AssignBills(int shipmentId, AssignBillsReq req)
        {
            // Reject at the write boundary rather than sanitize (mirrors the SP's 50066 hard-reject of
            // bad tokens): an empty request or any non-positive id is invalid input, not something to
            // silently drop. Only de-duplication is applied to the accepted ids.
            if (req?.PurchaseIds == null || req.PurchaseIds.Count == 0)
                throw new ArgumentException("No bills selected.");

            if (req.PurchaseIds.Any(id => id <= 0))
                throw new ArgumentException("One or more selected bill ids are invalid.");

            var ids = req.PurchaseIds
                .Distinct()
                .ToList();

            // Shipment_AssignBills' business guards (THROW 50061-50068) surface via ExceptionMiddleware,
            // which preserves Message on its default response - same as the other shipment SP-throw paths
            // (UnAllocation, CopyToBill). Keeping SqlClient out of the service layer.
            Uow.Shipments.AssignBills(shipmentId, string.Join(",", ids));

            return ids.Count;
        }

        public AllocationValidationResult ValidateAllocation(int purchaseId)
        {
            return Uow.Shipments.ValidateAllocation(purchaseId);
        }

        public List<AllocationMissingItem> ValidateAllocationDetail(int purchaseId, string method)
        {
            return Uow.Shipments.ValidateAllocationDetail(purchaseId, method);
        }

        // 2026-06-29: shipment-scoped validation (Plan 1) — pass-through to the repository.
        public AllocationValidationResult ValidateAllocationByShipment(int shipmentId)
        {
            return Uow.Shipments.ValidateAllocationByShipment(shipmentId);
        }

        public List<AllocationMissingItem> ValidateAllocationByShipmentDetail(int shipmentId, string method)
        {
            return Uow.Shipments.ValidateAllocationByShipmentDetail(shipmentId, method);
        }

        public PurchaseTariffRatePrecheckResult TariffRatePrecheck(int purchaseId)
        {
            var rows = Uow.Shipments.TariffRatePrecheck(purchaseId);

            return new PurchaseTariffRatePrecheckResult
            {
                MatchCount = rows.Count(r => r.Status == "MATCH"),
                DifferentCount = rows.Count(r => r.Status == "DIFFERENT"),
                MissingSetupCount = rows.Count(r => r.Status == "MISSING_SETUP"),
                NoCountryCount = rows.Count(r => r.Status == "NO_COUNTRY"),
                Rows = rows
            };
        }

        public PurchaseTariffRateRefreshResult RefreshTariffRates(int purchaseId)
        {
            return Uow.Shipments.RefreshTariffRates(purchaseId);
        }

        public ShipmentReallocationCleanupRes CleanupReallocationForShipment(int shipmentId)
        {
            _ = Uow.Shipments.Find(s => s.ShipmentId == shipmentId).FirstOrDefault()
                ?? throw new KeyNotFoundException("Shipment not found.");

            var assigned = Uow.ShipmentPurchases
                .Find(sp => sp.ShipmentId == shipmentId)
                .Join(Uow.Purchases.GetAll(),
                      sp => sp.PurchaseId,
                      p => p.PurchaseId,
                      (sp, p) => new { p.PurchaseId, p.PurchaseNumber })
                .OrderBy(p => p.PurchaseNumber)
                .ToList();

            Uow.Shipments.ResetCompletionAndReallocate(shipmentId);

            return new ShipmentReallocationCleanupRes
            {
                ShipmentId = shipmentId,
                Status = assigned.Count > 0 ? "GO_REALLOCATED" : "GO_NO_ACTION",
                ReallocatedPurchaseIds = assigned.Select(p => p.PurchaseId).ToList(),
                ReallocatedPurchaseNumbers = assigned.Select(p => p.PurchaseNumber).ToList(),
                ReallocatedCount = assigned.Count,
                Message = assigned.Count > 0
                    ? $"GO: reallocated {assigned.Count} assigned bill(s)."
                    : "GO: no assigned bills to reallocate."
            };
        }

        // Phase C: split-on-entry helper. Creates/updates per-bill charges (ShipmentPurchaseId NOT NULL)
        // for one shipment + charge type, then reallocates the affected bills.
        public ChargeSplitResponse SplitCharge(ChargeSplitReq req)
        {
            if (req == null) throw new ArgumentException("Request is required.");

            _ = Uow.Shipments.Find(s => s.ShipmentId == req.ShipmentId).FirstOrDefault()
                ?? throw new KeyNotFoundException("Shipment not found.");

            if (HasLockedShipmentBill(req.ShipmentId))
                throw new InvalidOperationException("Charge split is locked because the generated vendor bill is paid or locked.");

            var chargeType = (req.ChargeType ?? "").Trim();
            var isFreight = chargeType.Equals("Freight", StringComparison.OrdinalIgnoreCase);
            var isDuty = chargeType.Equals("CustomDuty", StringComparison.OrdinalIgnoreCase)
                      || chargeType.Equals("Tariff", StringComparison.OrdinalIgnoreCase);
            if (!isFreight && !isDuty)
                throw new ArgumentException($"Charge type '{req.ChargeType}' is not supported by the split helper (manual/other charges stay on the legacy path).");

            // Canonicalize to the exact-case values the ChargeType CHECK constraint requires
            // (a request like 'customduty' would otherwise be inserted verbatim and rejected).
            if (isFreight) chargeType = "Freight";
            else if (chargeType.Equals("CustomDuty", StringComparison.OrdinalIgnoreCase)) chargeType = "CustomDuty";
            else if (chargeType.Equals("Tariff", StringComparison.OrdinalIgnoreCase)) chargeType = "Tariff";

            if (req.Rows == null || req.Rows.Count == 0)
                throw new ArgumentException("Select at least one vendor bill.");

            var spIds = req.Rows.Select(r => r.ShipmentPurchaseId).Distinct().ToList();
            if (spIds.Count != req.Rows.Count)
                throw new ArgumentException("Each vendor bill can appear only once.");

            // Selected bills must belong to this shipment.
            var bills = Uow.ShipmentPurchases
                .Find(sp => sp.ShipmentId == req.ShipmentId && spIds.Contains(sp.ShipmentPurchaseId))
                .ToList();
            if (bills.Count != spIds.Count)
                throw new ArgumentException("One or more selected bills do not belong to this shipment.");

            var purchaseIds = bills.Select(b => b.PurchaseId).Distinct().ToList();

            // Drop-ship bills use the same split/basis rules as normal bills, then clear to COGS downstream.
            var selectedPurchases = Uow.Purchases
                .Find(p => purchaseIds.Contains(p.PurchaseId))
                .ToList();
            var selectedPurchaseIds = selectedPurchases
                .Select(p => p.PurchaseId)
                .ToHashSet();

            // One-purchase-one-shipment backstop (assignment enforces it; this is defence in depth).
            var offenders = Uow.ShipmentPurchases
                .Find(sp => purchaseIds.Contains(sp.PurchaseId))
                .ToList()
                .GroupBy(sp => sp.PurchaseId)
                .Where(g => g.Select(x => x.ShipmentId).Distinct().Count() > 1)
                .Select(g => g.Key)
                .ToList();
            if (offenders.Count > 0)
                throw new ArgumentException($"Purchase(s) {string.Join(", ", offenders)} belong to more than one shipment. Break them into one-to-one purchases first.");

            // Strict legacy-scope block. Generated charge-bill source rows are allowed here;
            // this save replaces that source row with per-bill rows for the same charge type.
            var hasLegacy = Uow.ShipmentCharges
                .Find(c => c.ShipmentId == req.ShipmentId
                        && c.ShipmentPurchaseId == null
                        && !c.IsGeneratedFromChargeBills
                        && c.ChargeAmount != 0m)
                .Any();
            if (hasLegacy)
                throw new ArgumentException("This shipment has a legacy shipment-wide charge. Remove or convert it before creating per-bill charges.");

            var usability = Uow.Shipments.BillBasisUsability(req.ShipmentId).ToDictionary(u => u.ShipmentPurchaseId);

            // 2026-07-13: user-facing bill labels use PurchaseNumber, not ShipmentPurchaseId.
            var billNoBySpId = bills
                .Join(selectedPurchases,
                      b => b.PurchaseId, p => p.PurchaseId, (b, p) => new { b.ShipmentPurchaseId, p.PurchaseNumber })
                .ToDictionary(x => x.ShipmentPurchaseId, x => x.PurchaseNumber);
            string BillLabel(int spId) => billNoBySpId.TryGetValue(spId, out var n) ? n.ToString() : spId.ToString();

            var toAdd = new List<ShipmentCharge>();
            string? billBasis = null;

            if (isFreight)
            {
                billBasis = (req.BillBasis ?? "").Trim().ToUpperInvariant();
                if (billBasis != "BY_PALLET" && billBasis != "BY_SPACE_PCT")
                    throw new ArgumentException("Freight requires BillBasis BY_PALLET or BY_SPACE_PCT.");
                if (req.CarrierTotal <= 0m)
                    throw new ArgumentException("Freight carrier total must be greater than zero.");

                var forced = (req.ForcedLineBasis ?? "").Trim().ToUpperInvariant();
                if (forced.Length > 0 && forced != "BY_QUANTITY")
                    throw new ArgumentException("The only supported freight line-basis override is BY_QUANTITY.");

                // Per-bill split weight.
                var weight = new Dictionary<int, decimal>();
                foreach (var r in req.Rows)
                {
                    decimal w;
                    if (billBasis == "BY_PALLET")
                    {
                        w = r.PalletCount ?? 0m;
                        if (w < 0m) throw new ArgumentException("Pallet count cannot be negative.");
                    }
                    else
                    {
                        w = r.SpacePercent ?? 0m;
                        if (w < 0m || w > 100m) throw new ArgumentException("Space percent must be between 0 and 100.");
                    }
                    weight[r.ShipmentPurchaseId] = w;
                }

                var totalWeight = weight.Values.Sum();
                if (billBasis == "BY_PALLET" && totalWeight <= 0m)
                    throw new ArgumentException("Total pallet count must be greater than zero.");
                if (billBasis == "BY_SPACE_PCT" && Math.Abs(totalWeight - 100m) > 0.01m)
                    throw new ArgumentException($"Space percentages must sum to 100 (got {totalWeight:0.##}).");

                // Denominator: pallets divide by the entered total; space% divides by 100.
                var denom = billBasis == "BY_SPACE_PCT" ? 100m : totalWeight;

                var amount = new Dictionary<int, decimal>();
                foreach (var r in req.Rows)
                    amount[r.ShipmentPurchaseId] = Math.Round(req.CarrierTotal * weight[r.ShipmentPurchaseId] / denom, 2);

                // Residual to the cent -> largest amount, tiebreak ShipmentPurchaseId ASC.
                var residual = req.CarrierTotal - amount.Values.Sum();
                if (residual != 0m)
                {
                    var top = amount.OrderByDescending(kv => kv.Value).ThenBy(kv => kv.Key).First().Key;
                    amount[top] += residual;
                }

                foreach (var r in req.Rows)
                {
                    var amt = amount[r.ShipmentPurchaseId];
                    if (amt <= 0m) continue; // a zero-share bill bears no freight; no charge row

                    if (!usability.TryGetValue(r.ShipmentPurchaseId, out var u))
                        throw new ArgumentException($"No basis-usability data for bill {BillLabel(r.ShipmentPurchaseId)}.");

                    // Resolve LineBasis per bill (SQL owns eligibility/weights; this is the cascade decision).
                    string lineBasis;
                    if (forced == "BY_QUANTITY")
                    {
                        if (u.QuantityOk != 1) throw new ArgumentException($"Bill {BillLabel(r.ShipmentPurchaseId)}: BY_QUANTITY requires total quantity greater than zero.");
                        lineBasis = "BY_QUANTITY";
                    }
                    else if (u.VolumeOk == 1) lineBasis = "BY_VOLUME";
                    else if (u.WeightOk == 1) lineBasis = "BY_WEIGHT";
                    else if (u.ValueOk == 1) lineBasis = "BY_VALUE";
                    else throw new ArgumentException($"Bill {BillLabel(r.ShipmentPurchaseId)}: no usable freight line basis (no volume, weight, or value).");

                    toAdd.Add(new ShipmentCharge
                    {
                        ShipmentId = req.ShipmentId,
                        ShipmentPurchaseId = r.ShipmentPurchaseId,
                        ChargeType = "Freight",
                        ChargeAmount = amt,
                        BillBasis = billBasis,
                        LineBasis = lineBasis,
                        AllocationMethod = lineBasis,
                        UpdatedAt = DateTime.UtcNow
                    });
                }
            }
            else // duty / tariff: split the broker's actual total by each bill's duty/tariff weight.
            {
                if (req.CarrierTotal < 0m)
                    throw new ArgumentException($"{chargeType} actual total cannot be negative.");

                if (req.CarrierTotal > 0m)
                {
                    var weight = new Dictionary<int, decimal>();
                    foreach (var r in req.Rows)
                    {
                        if (!usability.TryGetValue(r.ShipmentPurchaseId, out var u))
                            throw new ArgumentException($"No duty/tariff basis data for bill {BillLabel(r.ShipmentPurchaseId)}.");

                        weight[r.ShipmentPurchaseId] = u.TotalDutyTariffWeight;
                    }

                    var totalWeight = weight.Values.Sum();
                    if (totalWeight <= 0m)
                        throw new ArgumentException($"Selected bills have no dutiable value for {chargeType}.");

                    var amount = new Dictionary<int, decimal>();
                    foreach (var r in req.Rows)
                        amount[r.ShipmentPurchaseId] = Math.Round(req.CarrierTotal * weight[r.ShipmentPurchaseId] / totalWeight, 2);

                    // Residual to the cent -> largest amount, tiebreak ShipmentPurchaseId ASC.
                    var residual = req.CarrierTotal - amount.Values.Sum();
                    if (residual != 0m)
                    {
                        var top = amount.OrderByDescending(kv => kv.Value).ThenBy(kv => kv.Key).First().Key;
                        amount[top] += residual;
                    }

                    foreach (var r in req.Rows)
                    {
                        var amt = amount[r.ShipmentPurchaseId];
                        if (amt <= 0m) continue; // zero-weight/zero-share bills bear no duty/tariff row

                        toAdd.Add(new ShipmentCharge
                        {
                            ShipmentId = req.ShipmentId,
                            ShipmentPurchaseId = r.ShipmentPurchaseId,
                            ChargeType = chargeType,
                            ChargeAmount = amt,
                            BillBasis = null,
                            LineBasis = "BY_DUTY_TARIFF",
                            AllocationMethod = "BY_DUTY_TARIFF",
                            UpdatedAt = DateTime.UtcNow
                        });
                    }
                }
            }

            // The delete-replace below removes this (Shipment, ChargeType) group's existing per-bill rows;
            // their ShipmentAllocation rows cascade-delete (FK_ShipmentAllocation_ShipmentCharge = CASCADE).
            // Capture the OLD bills so any bill dropped from the re-split is ALSO reallocated - its LandedCost
            // must be recomputed once its charge (and cascaded allocations) are gone.
            var oldCharges = Uow.ShipmentCharges
                .Find(c => c.ShipmentId == req.ShipmentId && c.ChargeType == chargeType && c.ShipmentPurchaseId != null)
                .ToList();
            var oldSpIds = oldCharges.Select(c => c.ShipmentPurchaseId!.Value).Distinct().ToList();
            var oldPurchaseIds = oldSpIds.Count == 0
                ? new List<int>()
                : Uow.ShipmentPurchases.Find(sp => oldSpIds.Contains(sp.ShipmentPurchaseId)).Select(sp => sp.PurchaseId).ToList();
            var affectedPurchaseIds = selectedPurchaseIds.Union(oldPurchaseIds).Distinct().ToList();

            // Atomic multi-table save: split inputs (pallet/space) + the per-bill charge group,
            // all-or-nothing. ExecuteInTransaction wraps ExecuteUpdate/ExecuteDelete/SaveChanges in one DB tx,
            // so a failure can't leave pallet/space changed while the charges fail to save.
            Uow.ExecuteInTransaction(() =>
            {
                if (isFreight)
                {
                    // store the per-bill split inputs (clear the unused one so a re-split by another basis is clean)
                    foreach (var r in req.Rows)
                    {
                        var pc   = billBasis == "BY_PALLET"    ? r.PalletCount  : (decimal?)null;
                        var spct = billBasis == "BY_SPACE_PCT" ? r.SpacePercent : (decimal?)null;
                        Uow.ShipmentPurchases
                            .Find(sp => sp.ShipmentPurchaseId == r.ShipmentPurchaseId)
                            .ExecuteUpdate(s => s
                                .SetProperty(x => x.PalletCount, pc)
                                .SetProperty(x => x.SpacePercent, spct));
                    }
                }

                // group delete-replace: this shipment's per-bill rows for this charge type
                Uow.ShipmentCharges
                    .Find(c => c.ShipmentId == req.ShipmentId && c.ChargeType == chargeType && c.ShipmentPurchaseId != null)
                    .ExecuteDelete();

                // Charge-bill mode uses generated NULL-grain rows as source totals. Once this charge
                // type is split to bills, remove that generated summary so Purchase_Allocation routes
                // cleanly to the per-bill allocator without mixed-scope rows.
                Uow.ShipmentCharges
                    .Find(c => c.ShipmentId == req.ShipmentId
                            && c.ChargeType == chargeType
                            && c.ShipmentPurchaseId == null
                            && c.IsGeneratedFromChargeBills)
                    .ExecuteDelete();

                foreach (var c in toAdd)
                    Uow.ShipmentCharges.Add(c);

                Uow.Commit(); // SaveChanges assigns ChargeId to the added rows
            });

            // Apply = atomic save, THEN shipment-scoped provisional reallocation. The reset SP clears
            // completion, removes invalid generated AP bills, and reallocates current + old removed bills.
            Uow.Shipments.ResetCompletionAndReallocate(
                req.ShipmentId,
                rebuildChargeSummaries: false,
                extraPurchaseIds: string.Join(",", affectedPurchaseIds));

            // Build the response after commit - ChargeId is now populated on the added entities.
            var resultRows = toAdd
                .Select(c => new ChargeSplitResultRow
                {
                    ShipmentPurchaseId = c.ShipmentPurchaseId ?? 0,
                    ChargeId = c.ChargeId,
                    ChargeType = c.ChargeType ?? "",
                    ChargeAmount = c.ChargeAmount ?? 0m,
                    BillBasis = c.BillBasis,
                    LineBasis = c.LineBasis
                })
                .ToList();

            return new ChargeSplitResponse { Rows = resultRows, Reload = true };
        }

        private static class AllocationMethods
        {
            public const string ByValue = "BY_VALUE";
            public const string ByVolume = "BY_VOLUME";
            public const string ByDuty = "BY_DUTY";
            public const string ByTariff = "BY_TARIFF";
            public const string ByWeight = "BY_WEIGHT";
            public const string ByPallet = "BY_PALLET";
            public const string ByQuantity = "BY_QUANTITY";
        }

        private static string GetAllocationMethodFromChargeType(string? chargeTypeRaw)
        {
            var chargeType = (chargeTypeRaw ?? "").Trim();

            if (chargeType.Equals("Freight", StringComparison.OrdinalIgnoreCase))
                return AllocationMethods.ByVolume;

            if (chargeType.Equals("Insurance", StringComparison.OrdinalIgnoreCase))
                return AllocationMethods.ByValue;

            if (chargeType.Equals("CustomDuty", StringComparison.OrdinalIgnoreCase))
                return AllocationMethods.ByDuty;

            if (chargeType.Equals("Tariff", StringComparison.OrdinalIgnoreCase))
                return AllocationMethods.ByTariff;

            // Other / unknown
            return AllocationMethods.ByValue;
        }

        private bool HasLockedShipmentBill(int shipmentId)
        {
            return Uow.Purchases
                .Find(p => p.IsShipment
                        && p.SourceShipmentId == shipmentId
                        && (p.IsLocked || (p.PaymentApplied ?? 0m) > 0m))
                .Any();
        }
    }
}
