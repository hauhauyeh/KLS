using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ItemHistoryService : BaseService, IItemHistoryService
    {
        public ItemHistoryService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<ItemHistorySales> GetSalesHistory(ItemHistoryReq itemHistoryReq)
        {
            return Uow.ItemHistories.GetSalesHistory(itemHistoryReq);
        }

        public IEnumerable<ItemHistoryPurchase> GetPurchaseHistory(ItemHistoryReq itemHistoryReq)
        {
            return Uow.ItemHistories.GetPurchaseHistory(itemHistoryReq);
        }

        public IEnumerable<ItemHistoryInventory> GetInventoryHistory(ItemHistoryReq itemHistoryReq)
        {
            return Uow.ItemHistories.GetInventoryHistory(itemHistoryReq);
        }
    }
}
