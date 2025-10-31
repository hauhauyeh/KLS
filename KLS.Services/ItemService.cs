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

        public Item? GetByItemCode(string? itemCode)
        {
            return Uow.Items.Find(c => c.ItemCode == itemCode).FirstOrDefault();
        }

        public Item? GetByItemName(string itemName)
        {
            return Uow.Items.Find(c => c.ItemName == itemName).FirstOrDefault();
        }

        public Item? GetByBarcodeW(string barcodeW)
        {
            return Uow.Items.Find(c => c.BarcodeW == barcodeW).FirstOrDefault();
        }

        public Item? GetByBarcodeR(string barcodeR)
        {
            return Uow.Items.Find(c => c.BarcodeR == barcodeR).FirstOrDefault();
        }

        public Item? GetBySearch(string itemCode)
        {
            if (string.IsNullOrEmpty(itemCode))
                return null;

            var item = GetByItemCode(itemCode);

            if (item == null)
            {
                item = GetByItemName(itemCode);

                if (item == null)
                {
                    item = GetByBarcodeW(itemCode);

                    if (item == null)
                        item = GetByBarcodeR(itemCode);
                }
            }

            return item;
        }

        public ICollection<ItemSearch>? SearchItem(ItemSearchReq searchReq)
        {
            return Uow.Items.SearchItem(searchReq)?.ToList();
        }
    }
}
