using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IItemRepository : IRepository<Item>
    {
        IQueryable<ItemList> GetAllItems(ItemListReq itemListReq);

        int CountAllItems(ItemListReq itemListReq);

        IQueryable<ItemSearch>? SearchItem(ItemSearchReq searchReq);

        void DeleteItem(int itemId);

        ItemCalcUnit GetCalcUnit(ItemPackingReq packingReq);

        ItemCalcRetail CalcRetailPriceProfit(ItemCalcRetail calcRetail);
    }
}
