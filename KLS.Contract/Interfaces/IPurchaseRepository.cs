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
        IQueryable<PurchaseList> GetAllPurchase(PurchaseListReq purchaseListReq);

        int CountAllPurchase(PurchaseListReq purchaseListReq);
    }
}
