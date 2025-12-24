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

        void FreightBillLink(int purchaseId);
    }
}
