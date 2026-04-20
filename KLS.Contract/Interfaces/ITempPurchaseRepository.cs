using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ITempPurchaseRepository : IRepository<TempPurchase>
    {
        IQueryable<TempPurchaseItem>? GetList(TempPurchaseReq tempReq);

        void Reorder(TempPurchaseReorderReq reorderReq);
    }
}
