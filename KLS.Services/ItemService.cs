using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.VisualBasic.FileIO;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ItemService : BaseService, IItemService
    {
        public ItemService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<ItemList> GetItems(ItemListReq itemListReq)
        {
            var itemlist = Uow.Items.GetItems(itemListReq);

            var totalRecords = Uow.Items.CountAllItems(itemListReq);

            return new PagingResponse<ItemList>(totalRecords, itemListReq.Pageno, itemListReq.Pagesize)
            {
                RowData = itemlist,
            };
        }

        public ICollection<ItemSearch>? SearchItem(ItemSearchReq searchReq)
        {
            return Uow.Items.SearchItem(searchReq)?.ToList();
        }
    }
}
