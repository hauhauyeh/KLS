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
            return Uow.Shipments.Find(c => c.ShipmentId == shipmentId).Include(c => c.Charges).FirstOrDefault();
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
            existing.ETA = shipment.ETA;
            existing.Status = shipment.Status;
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

            // 1) DELETE removed charges (exists in DB but not coming from UI)
            var incomingIds = incomingCharges
                .Select(x => x.ChargeId)
                .ToHashSet();

            Uow.ShipmentCharges
                .Find(x => x.ShipmentId == shipment.ShipmentId && !incomingIds.Contains(x.ChargeId))
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

            Uow.Shipments.UpdateCharges(shipment.ShipmentId);

            return existing;
        }

        public void UpdateNotes(Shipment shipment)
        {
            Uow.Shipments.Find(c => c.ShipmentId == shipment.ShipmentId).ExecuteUpdate(setters => setters
           .SetProperty(x => x.Notes, x => shipment.Notes)
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
            Uow.Shipments.GenerateBill(shipmentId);

            return GetById(shipmentId);
        }

        public void UnAllocation(int shipmentPurchaseId)
        {
            Uow.Shipments.UnAllocation(shipmentPurchaseId);
        }

        public IEnumerable<AssignedPurchase>? AssignedPurchases(int shipmentId)
        {
            return Uow.Shipments.AssignedPurchases(shipmentId);
        }

        public AllocationValidationResult ValidateAllocation(int purchaseId)
        {
            return Uow.Shipments.ValidateAllocation(purchaseId);
        }

        public List<AllocationMissingItem> ValidateAllocationDetail(int purchaseId, string method)
        {
            return Uow.Shipments.ValidateAllocationDetail(purchaseId, method);
        }

        public ReallocateResponse Reallocate(ReallocateReq req)
        {
            // Update charge methods via direct SQL — avoids EF tracking conflicts
            if (req.Charges != null)
            {
                foreach (var ov in req.Charges)
                {
                    Uow.ShipmentCharges.Find(c => c.ChargeId == ov.ChargeId)
                        .ExecuteUpdate(setters => setters
                            .SetProperty(c => c.AllocationMethod, ov.AllocationMethod)
                            .SetProperty(c => c.UpdatedAt, DateTime.UtcNow));
                }
            }

            // Run allocation
            Uow.Shipments.Allocation(req.PurchaseId, req.RefreshVolume);

            // Return results
            var results = Uow.Shipments.AllocationResult(req.PurchaseId);
            return new ReallocateResponse { Results = results.ToList() };
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
    }
}
