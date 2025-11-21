using KLS.Common;
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
            return Uow.ItemStorages.GetAll().OrderBy(s => s.Zone).ToList();
        }

        //public IEnumerable<ItemStorageTree> GetAllStorageTree()
        //{
        //    var storage = Uow.ItemStorages.GetAll().OrderBy(c => c.Zone).ToList();

        //    return BuildTree(storage, null);
        //}

        //private IEnumerable<ItemStorageTree> BuildTree(IEnumerable<ItemStorage> itemStorages, int? parentId)
        //{
        //    return itemStorages.Where(x => x.ParentId == parentId).Select(x => new ItemStorageTree
        //    {
        //        StorageId = x.StorageId,
        //        Zone = x.Zone,
        //        DisplayName = x.DisplayName,
        //        ParentId = x.ParentId,
        //        ChildItemStorage = BuildTree(itemStorages, x.StorageId)
        //    });
        //}

        public ItemStorage GetById(int id)
        {
            return Uow.ItemStorages.GetById(id);
        }

        public bool NameExists(ItemStorage itemStorage)
        {
            return Uow.ItemStorages.Exists(c => c.Zone == itemStorage.Zone && c.StorageId != itemStorage.StorageId);
        }

        public ItemStorage CreateItemStorage(ItemStorage itemStorage)
        {
            Uow.ItemStorages.Add(itemStorage);
            Uow.Commit();

            return itemStorage;
        }

        public ItemStorage UpdateItemStorage(ItemStorage itemStorage)
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

        public void DeleteItemStorage(int storageId)
        {
            Uow.ItemStorages.RemoveById(storageId);
            Uow.Commit();
        }
    }
}
