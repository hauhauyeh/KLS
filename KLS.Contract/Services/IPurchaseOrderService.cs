using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IPurchaseOrderService
    {
        PagingResponse<PurchaseOrderList> GetPagedList(PurchaseOrderReq purchaseOrderReq);

        PurchaseOrderList? Checkout(PurchaseOrderCheckoutReq checkoutReq);

        void Delete(int purchaseId);

        IEnumerable<PODetail> GetPODetail(int purchaseId);

        PurchaseOrderList? CopyToBill(POCopyToBillReq copyToBillReq);

        string PrintPO(int purchaseId);

        PurchaseOrderList? UpdateToBillStage(int purchaseId);
    }
}
