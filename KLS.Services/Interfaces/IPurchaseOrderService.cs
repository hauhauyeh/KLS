using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IPurchaseOrderService
    {
        PagingResponse<PurchaseOrderList> GetAllPurchaseOrders(PurchaseOrderReq purchaseOrderReq);

        PurchaseOrder GetById(int pOId);

        void UpdateNotes(PurchaseOrder purchaseOrder);

        void UpdateContainerNumber(PurchaseOrder purchaseOrder);

        void UpdateVendorDocNumber(PurchaseOrder purchaseOrder);

        void InjectPurchaseOrder(PurchaseOrderInjectReq injectReq);

        PurchaseOrder Checkout(PurchaseOrderCheckoutReq checkoutReq);

        void DeletePurchaseOrder(int poId);

        void SaveAdvancePayment(POAdvancePaymentReq advancePaymentReq);

        void DeleteAdvancePayment(int poId);
    }
}
