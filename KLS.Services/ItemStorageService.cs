using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
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

        public IEnumerable<ItemStorage>? GetList()
        {
            return Uow.ItemStorages.GetAll().OrderBy(s => s.SortOrder).ToList();
        }

        public ItemStorage GetById(int id)
        {
            return Uow.ItemStorages.GetById(id);
        }

        public bool NameExists(ItemStorage itemStorage)
        {
            return Uow.ItemStorages.Exists(c => c.Zone == itemStorage.Zone && c.StorageId != itemStorage.StorageId);
        }

        public ItemStorage Create(ItemStorage itemStorage)
        {
            Uow.ItemStorages.Add(itemStorage);
            Uow.Commit();

            return itemStorage;
        }

        public ItemStorage Update(ItemStorage itemStorage)
        {
            var existing = GetById(itemStorage.StorageId);

            if (existing != null)
            {
                existing.DisplayName = itemStorage.DisplayName;
                existing.Zone = itemStorage.Zone;
                existing.Section = itemStorage.Section;
                existing.Aisle = itemStorage.Aisle;
                existing.Bay = itemStorage.Bay;
                existing.Bin = itemStorage.Bin;
                existing.Inactive = itemStorage.Inactive;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.ItemStorages.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void Delete(int storageId)
        {
            Uow.ItemStorages.RemoveById(storageId);
            Uow.Commit();
        }
    }
}
