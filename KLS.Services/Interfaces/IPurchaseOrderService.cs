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

        void UpdateNotes(int poId, string? notes);

        void UpdateContainerNumber(PurchaseOrder purchaseOrder);

        void UpdateVendorDocNumber(PurchaseOrder purchaseOrder);

        void InjectPurchaseOrder(PurchaseOrderInjectReq injectReq);

        PurchaseOrderList? Checkout(PurchaseOrderCheckoutReq checkoutReq);

        void DeletePurchaseOrder(int poId);

        void SaveAdvancePayment(POAdvancePaymentReq advancePaymentReq);

        void DeleteAdvancePayment(int poId);

        IEnumerable<PODetail> GetPODetail(int poId);

        PurchaseOrderList? CopyToBill(POCopyToBillReq copyToBillReq);
    }
}
