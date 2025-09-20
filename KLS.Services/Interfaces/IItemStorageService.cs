using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IItemStorageService
    {
        IEnumerable<ItemStorage>? GetAllStorages();

        IEnumerable<ItemStorageTree> GetAllStorageTree();

        ItemStorage GetById(int id);

        bool NameExists(ItemStorage itemStorage);

        ItemStorage CreateItemStorage(ItemStorage itemStorage);

        ItemStorage UpdateItemStorage(ItemStorage itemStorage);

        void DeleteItemStorage(int storageId);
    }
}
