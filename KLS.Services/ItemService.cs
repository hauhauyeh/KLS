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

        public ICollection<ItemSearch>? SearchItem(ItemSearchReq searchReq)
        {
            return Uow.Items.SearchItem(searchReq)?.ToList();
        }
    }
}
