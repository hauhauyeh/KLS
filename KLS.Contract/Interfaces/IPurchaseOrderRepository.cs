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
        IQueryable<PurchaseOrderList> GetPagedList(PurchaseOrderReq purchaseOrderReq);

        int Count(PurchaseOrderReq purchaseOrderReq);

        void Inject(PurchaseOrderInjectReq injectReq);

        int Checkout(PurchaseOrderCheckoutReq checkoutReq);

        void SaveAdvancePayment(POAdvancePaymentReq advancePaymentReq);

        void DeleteAdvancePayment(int poId);

        IQueryable<PODetail> GetPODetail(int purchaseId);

        void CopyToBill(POCopyToBillReq copyToBillReq);
    }
}
