using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IShipmentRepository : IRepository<Shipment>
    {
        IQueryable<ShipmentList> GetPagedList(ShipmentListReq shipmentListReq);

        int Count(ShipmentListReq shipmentListReq);

        void Allocation(int purchaseId, bool refreshVolume = false);

        void UnAllocation(int shipmentPurchaseId);

        void Delete(int shipmentId);

        void GenerateBill(int shipmentId);

        void GenerateChargeBills(int shipmentId);

        bool HasChargeBills(int shipmentId);

        void RebuildChargesFromChargeBills(int shipmentId);

        void RefreshSingleBillAllocation(int shipmentId);

        void UpdateCharges(int shipmentId);

        void AssignShipment(POCopyToBillReq copyToBillReq);

        IEnumerable<AssignedPurchase>? AssignedPurchases(int shipmentId);

        // Multi-Bill Assign: eligible bills for the picker + the atomic batch-assign write.
        IEnumerable<EligibleBill>? EligibleBills(int shipmentId, string? search);

        void AssignBills(int shipmentId, string purchaseIds);

        // Phase C: per-bill basis usability + totals, so the split helper resolves freight LineBasis
        // and derives duty amounts in the service without duplicating landed-cost math.
        IEnumerable<BillBasisUsability> BillBasisUsability(int shipmentId);

        IEnumerable<ShipmentReallocationCandidate> ReallocationCandidates(int shipmentId);

        AllocationValidationResult ValidateAllocation(int purchaseId);

        List<AllocationMissingItem> ValidateAllocationDetail(int purchaseId, string method);

        // 2026-06-29: shipment-scoped validation (Plan 1) — same SPs called with @ShipmentId so the
        // coverage matches the allocation guard's scope (all bills in the shipment).
        AllocationValidationResult ValidateAllocationByShipment(int shipmentId);

        List<AllocationMissingItem> ValidateAllocationByShipmentDetail(int shipmentId, string method);

        IEnumerable<AllocationResultItem> AllocationResult(int purchaseId);
    }
}
