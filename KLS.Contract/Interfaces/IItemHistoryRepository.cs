using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IItemHistoryRepository : IRepository<ItemHistorySales>
    {
        IQueryable<ItemHistorySales> GetSalesHistory(ItemHistoryReq itemHistoryReq);

        IQueryable<ItemHistoryPurchase> GetPurchaseHistory(ItemHistoryReq itemHistoryReq);
    }
}
