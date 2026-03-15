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

        IEnumerable<ItemSearch> ActiveItems();

        Item? GetById(int itemId);

        IEnumerable<Item> GetByIds(IEnumerable<int> itemIds);

        Item? GetBySearch(string itemCode);

        IEnumerable<ItemSearch>? Search(ItemSearchReq searchReq);

        void Delete(int itemId);

        void Inactive(int itemId);

        bool ItemCodeExists(Item item);

        bool ItemNameExists(Item item);

        Item? Save(Item item);

        IEnumerable<ItemCalcUnit> GetCalcUnit(ItemPackingReq packingReq);

        ItemCalcRetail CalcRetailPriceProfit(ItemCalcRetail calcRetail);

        void UpdateBaseP1(ItemUpdateReq updateReq);

        ItemDefaultFreight GetDefaultFreight(int itemId);

        void SaveFreight(ItemDefaultFreight defaultFreight);

        IEnumerable<ItemSearch> GetSearchList(int payeeId);


        PagingResponse<ItemWebList> GetWebPagedList(ItemWebListReq webListReq);

        IEnumerable<ItemWebSearchList>? WebSearch(string searchTerm);
    }
}
