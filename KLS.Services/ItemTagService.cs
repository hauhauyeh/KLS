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
    public class ItemTagService : BaseService, IItemTagService
    {
        public ItemTagService(IUnitOfWork uow) : base(uow)
        {
        }

        public IEnumerable<ItemTag> GetList()
        {
            return Uow.ItemTags.GetAll().OrderBy(t => t.TagName);
        }

        public ItemTag GetById(int itemTagId)
        {
            return Uow.ItemTags.GetById(itemTagId);
        }

        public bool NameExists(ItemTag itemTag)
        {
            return Uow.ItemTags.Exists(t =>
                t.TagName.ToLower() == itemTag.TagName.ToLower()
                && t.ItemTagId != itemTag.ItemTagId);
        }

        public ItemTag Create(ItemTag itemTag)
        {
            Uow.ItemTags.Add(itemTag);
            Uow.Commit();

            return itemTag;
        }

        public ItemTag? Update(ItemTag itemTag)
        {
            var existing = GetById(itemTag.ItemTagId);

            if (existing != null)
            {
                existing.TagName = itemTag.TagName;
                existing.Inactive = itemTag.Inactive;

                Uow.ItemTags.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void Delete(int itemTagId)
        {
            Uow.ItemTags.RemoveById(itemTagId);
            Uow.Commit();
        }
    }
}
