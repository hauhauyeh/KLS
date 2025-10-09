using KLS.Models;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IItemCategoryService
    {
        IQueryable<ItemCategory> GetAllCategory();

        IEnumerable<ItemCategoryTree> GetAllCategoryTree();

        ItemCategory GetById(int id);

        bool NameExists(ItemCategory itemCategory);

        ItemCategory CreateCategory(ItemCategory itemCategory);

        ItemCategory UpdateCategory(ItemCategory itemCategory);

        void DeleteCategory(int categoryId);

        void SaveImage(ItemCategory category, HttpRequest request);

        void DeleteImage(int catId);
    }
}
