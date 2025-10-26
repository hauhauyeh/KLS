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

        void UpdateNotes(PurchaseOrder purchaseOrder);

        void UpdateVendorDocNumber(PurchaseOrder purchaseOrder);
    }
}
