using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IItemStorageService
    {
        IEnumerable<ItemStorage>? GetList();

        ItemStorage GetById(int id);

        bool NameExists(ItemStorage itemStorage);

        ItemStorage Create(ItemStorage itemStorage);

        ItemStorage Update(ItemStorage itemStorage);

        void Delete(int storageId);
    }
}
