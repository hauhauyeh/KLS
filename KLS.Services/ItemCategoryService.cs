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
    public class ItemCategoryService : BaseService, IItemCategoryService
    {
        private readonly List<ItemCategory> _FlatCategory = new();

        public ItemCategoryService(IUnitOfWork uow) : base(uow)
        {
        }

        public IQueryable<ItemCategory> GetAllCategory()
        {
            return Uow.ItemCategories.GetAll().OrderBy(c => c.CategoryName);
        }

        public IEnumerable<ItemCategoryTree> GetAllCategoryTree()
        {
            var category = Uow.ItemCategories.GetAll().OrderBy(c => c.CategoryName).ToList();

            return BuildTree(category, null);
        }

        public ItemCategory GetById(int id)
        {
            return Uow.ItemCategories.GetById(id);
        }

        //public void FlatTree(IEnumerable<ItemCategory> nodes)
        //{
        //    foreach (var node in nodes)
        //    {
        //        _FlatCategory.Add(new ItemCategory
        //        {
        //            CategoryId = node.CategoryId,
        //            CategoryName = node.CategoryName,
        //            ParentId = node.ParentId
        //        });

        //        if (node.ChildCategories != null)
        //            FlatTree(node.ChildCategories);
        //    }
        //}

        private IEnumerable<ItemCategoryTree> BuildTree(IEnumerable<ItemCategory> itemCategories, int? parentId)
        {
            return itemCategories.Where(x => x.ParentId == parentId).Select(x => new ItemCategoryTree
            {
                CategoryId = x.CategoryId,
                CategoryName = x.CategoryName,
                DisplayName = x.DisplayName,
                ParentId = x.ParentId,
                ChildCategories = BuildTree(itemCategories, x.CategoryId)
            });
        }

        public bool NameExists(ItemCategory itemCategory)
        {
            return Uow.ItemCategories.Exists(c => c.CategoryName == itemCategory.CategoryName && c.CategoryId != itemCategory.CategoryId);
        }

        public ItemCategory CreateCategory(ItemCategory itemCategory)
        {
            Uow.ItemCategories.Add(itemCategory);
            Uow.Commit();

            return itemCategory;
        }

        public ItemCategory UpdateCategory(ItemCategory itemCategory)
        {
            var existing = GetById(itemCategory.CategoryId);

            if (existing != null)
            {
                existing.ParentId = itemCategory.ParentId;
                existing.CategoryName = itemCategory.CategoryName;
                existing.DisplayName = itemCategory.DisplayName;
                existing.ForeignName = itemCategory.ForeignName;
                existing.InvoiceName = itemCategory.InvoiceName;
                existing.Description = itemCategory.Description;
                existing.Slug = itemCategory.Slug;
                existing.ImageUrl = itemCategory.ImageUrl;
                existing.IsInactive = itemCategory.IsInactive;
                existing.SortOrder = itemCategory.SortOrder;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.ItemCategories.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void DeleteItemCategory(int categoryId)
        {
            Uow.ItemCategories.RemoveById(categoryId);
            Uow.Commit();
        }

        //public void DeleteItemCategory(int categoryId)
        //{
        //    var children = Uow.ItemCategories.GetAll()
        //        .Where(c => c.ParentId == categoryId)
        //        .ToList();

        //    foreach (var child in children)
        //    {
        //        DeleteItemCategory(child.CategoryId);
        //    }

        //    Uow.ItemCategories.RemoveById(categoryId);
        //    Uow.Commit();
        //}
    }
}
