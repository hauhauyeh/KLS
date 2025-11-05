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
        PagingResponse<ItemList> GetItems(ItemListReq itemListReq);

        Item? GetBySearch(string itemCode);

        IEnumerable<ItemSearch>? SearchItem(ItemSearchReq searchReq);
    }
}
