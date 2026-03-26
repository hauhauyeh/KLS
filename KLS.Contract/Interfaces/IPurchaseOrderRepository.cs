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
        IQueryable<POList> GetPagedList(POListReq purchaseOrderReq);

        int Count(POListReq purchaseOrderReq);

        void Inject(POInjectReq injectReq);

        int Checkout(POCheckoutReq checkoutReq);

        IQueryable<PODetail> GetPODetail(int purchaseId);

        void CopyToBill(POCopyToBillReq copyToBillReq);

    }
}
