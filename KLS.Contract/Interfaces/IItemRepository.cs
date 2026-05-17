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
        IQueryable<ItemList> GetPagedList(ItemListReq itemListReq);

        int Count(ItemListReq itemListReq);

        IQueryable<ItemSearch>? Search(ItemSearchReq searchReq);

        void Delete(int itemId);

        IQueryable<ItemCalcUnit> GetCalcUnit(ItemPackingReq packingReq);

        ItemCalcRetail CalcRetailPriceProfit(ItemCalcRetail calcRetail);

        void UpdateBaseP1(ItemUpdateReq updateReq);

        IQueryable<ItemWebRowList> GetWebPagedList(ItemWebListReq webListReq);

        int WebCount(ItemWebListReq webListReq);

        IEnumerable<ItemSearch> GetSearchList(int payeeId, string mode = "customer");
    }
}
