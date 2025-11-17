using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IItemService
    {
        PagingResponse<ItemList> GetAllItems(ItemListReq itemListReq);

        Item? GetById(int itemId);

        Item? GetBySearch(string itemCode);

        IEnumerable<ItemSearch>? SearchItem(ItemSearchReq searchReq);

        void DeleteItem(int itemId);

        void Inactive(int itemId);

        bool ItemCodeExists(Item item);

        bool ItemNameExists(Item item);

        Item? SaveItem(Item item);

        ItemCalcUnit GetCalcUnit(ItemPackingReq packingReq);

        ItemCalcRetail CalcRetailPriceProfit(ItemCalcRetail calcRetail);

        void UpdateDefautCost(int itemId, decimal? defaultCost);

        void SendCostChangeNotification(Item item);
    }
}
