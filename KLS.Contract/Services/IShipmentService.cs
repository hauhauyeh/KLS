using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IShipmentService
    {
        PagingResponse<ShipmentList> GetPagedList(ShipmentListReq shipmentListReq);

        IEnumerable<ShipmentList> GetOpenShipments();

        Shipment? GetById(int shipmentId);

        bool Exists(Shipment shipment);

        Shipment Create(Shipment shipment);

        Shipment Update(Shipment shipment);

        void UpdateNotes(Shipment shipment);

        void Delete(int shipmentId);

        Shipment? Reopen(int shipmentId);

        Shipment? GenerateBill(int shipmentId);

        void UnAllocation(int shipmentPurchaseId);

        IEnumerable<AssignedPurchase>? AssignedPurchases(int shipmentId);

        IEnumerable<BillBasisUsability>? BillBasisUsability(int shipmentId);

        // Multi-Bill Assign: eligible-bill picker + batch assign (returns count assigned).
        IEnumerable<EligibleBill>? EligibleBills(int shipmentId, string? search);

        int AssignBills(int shipmentId, AssignBillsReq req);

        AllocationValidationResult ValidateAllocation(int purchaseId);

        List<AllocationMissingItem> ValidateAllocationDetail(int purchaseId, string method);

        // 2026-06-29: shipment-scoped validation (Plan 1) — coverage at the guard's scope.
        AllocationValidationResult ValidateAllocationByShipment(int shipmentId);

        List<AllocationMissingItem> ValidateAllocationByShipmentDetail(int shipmentId, string method);

        PurchaseTariffRatePrecheckResult TariffRatePrecheck(int purchaseId);

        PurchaseTariffRateRefreshResult RefreshTariffRates(int purchaseId);

        ShipmentReallocationCleanupRes CleanupReallocationForShipment(int shipmentId);

        // Phase C: split-on-entry helper - creates/updates per-bill charges for one shipment + charge type.
        ChargeSplitResponse SplitCharge(ChargeSplitReq req);
    }
}
