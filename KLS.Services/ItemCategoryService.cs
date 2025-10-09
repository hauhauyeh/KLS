using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Hosting.Internal;
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
        private readonly IWebHostEnvironment hostingEnvironment;

        public ItemCategoryService(IUnitOfWork uow, IWebHostEnvironment HostingEnvironment) : base(uow)
        {
            hostingEnvironment = HostingEnvironment;
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
                ImageUrl = x.ImageUrl,
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
            itemCategory.Slug = SlugHelper.GenerateSlug(itemCategory.DisplayName);

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
                //existing.ImageUrl = itemCategory.ImageUrl;
                existing.Inactive = itemCategory.Inactive;
                existing.SortOrder = itemCategory.SortOrder;
                existing.CustomDutyRate = itemCategory.CustomDutyRate;
                existing.CatFormFile = itemCategory.CatFormFile;
                existing.Slug = SlugHelper.GenerateSlug(itemCategory.DisplayName);
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.ItemCategories.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void DeleteCategory(int categoryId)
        {
            Uow.ItemCategories.RemoveById(categoryId);
            Uow.Commit();
        }

        public void SaveImage(ItemCategory category, HttpRequest request)
        {
            if (category.CatFormFile != null)
            {
                string extension = Path.GetExtension(category.CatFormFile.FileName);
                string fileName = category.CategoryId + extension;
                string path = Path.Combine(hostingEnvironment.WebRootPath + "/KLS/category/", fileName);

                using var fileStream = new FileStream(path, FileMode.Create);
                category.CatFormFile.CopyTo(fileStream);

                var imagepath = request.Scheme + "://" + request.Host + request.PathBase + "/KLS/category/" + fileName + "?" + category.UpdatedAt?.Ticks;

                category.ImageUrl = imagepath;

                var oldcat = GetById(category.CategoryId);

                if (oldcat != null)
                {
                    oldcat.ImageUrl = category.ImageUrl;
                    Uow.ItemCategories.Update(oldcat);
                    Uow.Commit();
                }
            }
        }

        public void DeleteImage(int catId)
        {
            var cat = GetById(catId);

            if (cat != null)
            {
                DeleteImageFromFolder(cat);

                cat.ImageUrl = null;
                Uow.ItemCategories.Update(cat);
                Uow.Commit();
            }
        }

        private void DeleteImageFromFolder(ItemCategory itemCategory)
        {
            if (!string.IsNullOrEmpty(itemCategory.ImageUrl))
            {
                var fileName = Path.GetFileName(itemCategory.ImageUrl);
                var fileNames = fileName.Split("?");
                var imageFileName = fileNames[0];

                string filepath = Path.Combine(hostingEnvironment.WebRootPath, "KLS", "category", imageFileName);

                if (System.IO.File.Exists(filepath))
                    System.IO.File.Delete(filepath);
            }
        }
    }
}
