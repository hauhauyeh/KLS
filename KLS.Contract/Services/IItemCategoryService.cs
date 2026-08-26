using KLS.Models;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IItemCategoryService
    {
        IQueryable<ItemCategory> GetAllCategory();

        IEnumerable<ItemCategory> GetTree();

        IEnumerable<ItemCategoryTree> GetWebTree();

        ItemCategory GetById(int id);

        bool NameExists(ItemCategory itemCategory);

        ItemCategory Create(ItemCategory itemCategory);

        ItemCategory Update(ItemCategory itemCategory);

        void Delete(int categoryId);

        void SaveImage(ItemCategory category, HttpRequest request);

        ItemCategory UploadImage(int categoryId, IFormFile file, HttpRequest request);

        void DeleteImage(int catId);

        void ReprocessImageOriginal(int categoryId);

        Task<CategoryImageProcessResult> ProcessImageBgLocal(int categoryId);

        Task<CategoryImageProcessResult> ProcessImageBgApi(int categoryId);

        Task FinalizeImage(CategoryImageFinalizeReq req);

        void ReorderNode(ItemCategoryReorderReq dto);
    }
}
