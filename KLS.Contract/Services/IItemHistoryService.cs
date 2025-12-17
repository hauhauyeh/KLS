using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IItemHistoryService
    {
        IEnumerable<ItemHistorySales> GetSalesHistory(ItemHistoryReq itemHistoryReq);

        IEnumerable<ItemHistoryPurchase> GetPurchaseHistory(ItemHistoryReq itemHistoryReq);

        IEnumerable<ItemHistoryInventory> GetInventoryHistory(ItemHistoryReq itemHistoryReq);
    }
}
