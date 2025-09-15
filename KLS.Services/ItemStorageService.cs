using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ItemStorageService : BaseService, IItemStorageService
    {
        public ItemStorageService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<ItemStorage>? GetAllStorages()
        {
            return Uow.ItemStorages.GetAll();
        }
    }
}
