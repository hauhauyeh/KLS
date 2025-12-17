using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IItemTagService
    {
        IQueryable<ItemTag> GetAllItemTags();

        ItemTag GetById(int itemTagId);

        bool ExistsTagName(ItemTag itemTag);

        ItemTag CreateItemTag(ItemTag itemTag);

        ItemTag? UpdateItemTag(ItemTag itemTag);

        void DeleteItemTag(int itemTagId);
    }
}
