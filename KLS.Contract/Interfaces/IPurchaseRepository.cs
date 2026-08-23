using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IPurchaseRepository : IRepository<Purchase>
    {
        IQueryable<PurchaseList> GetPagedList(PurchaseListReq purchaseListReq);

        int Count(PurchaseListReq purchaseListReq);

        void Inject(PurchaseInjectReq injectReq);

        int Checkout(PurchaseCheckoutReq checkoutReq);

        void UpdateNameDate(PurchaseUpdateReq updateReq);

        void UpdatePartially(int purchaseId);

        void DropShipPORestrictedUpdate(int purchaseId, bool canUpdateShipQty);

        void DropShipBillRestrictedUpdate(int purchaseId);

        void FreightBillLink(int purchaseId);

        void SyncDropShipSalesTransitFromPO(int purchaseId);

        IQueryable<AssignedShipmentRow> AssignedShipments(int purchaseId, bool isShipment);

        IQueryable<PurchaseDetailList> GetPurchaseDetails(int purchaseId);

        IQueryable<PurchaseItemCostList> GetItemCostChange(int purchaseId);
    }
}
