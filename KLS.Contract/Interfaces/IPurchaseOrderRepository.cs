using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IPurchaseOrderRepository : IRepository<PurchaseOrder>
    {
        IQueryable<PurchaseOrderList> GetPurchaseOrders(PurchaseOrderReq purchaseOrderReq);

        int CountAllPurchaseOrders(PurchaseOrderReq purchaseOrderReq);

        void InjectPurchaseOrder(PurchaseOrderInjectReq injectReq);

        int Checkout(PurchaseOrderCheckoutReq checkoutReq);
    }
}
