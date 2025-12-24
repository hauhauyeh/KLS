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
        IEnumerable<ItemTag> GetList();

        ItemTag GetById(int itemTagId);

        bool NameExists(ItemTag itemTag);

        ItemTag Create(ItemTag itemTag);

        ItemTag? Update(ItemTag itemTag);

        void Delete(int itemTagId);
    }
}
