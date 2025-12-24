using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IItemService
    {
        PagingResponse<ItemList> GetPagedList(ItemListReq itemListReq);

        Item? GetById(int itemId);

        Item? GetBySearch(string itemCode);

        IEnumerable<ItemSearch>? Search(ItemSearchReq searchReq);

        void Delete(int itemId);

        void Inactive(int itemId);

        bool ItemCodeExists(Item item);

        bool ItemNameExists(Item item);

        Item? Save(Item item);

        IEnumerable<ItemCalcUnit> GetCalcUnit(ItemPackingReq packingReq);

        ItemCalcRetail CalcRetailPriceProfit(ItemCalcRetail calcRetail);

        //void UpdateDefautCost(int itemId, decimal? defaultCost);

        //Item UpdateP1(int itemId, decimal? p1);

        //Item UpdateRetailPrice(int itemId, decimal? retailPrice);

        //Item UpdateRetailProfit(int itemId, decimal? retailProfit);

        //void SendCostChangeNotification(Item item);
    }
}
