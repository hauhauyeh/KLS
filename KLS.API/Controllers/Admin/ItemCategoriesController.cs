using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Product Category Management", GroupName = "Product")]
    public class ItemCategoriesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemCategoryService _itemCategoryService;
        private IWebHostEnvironment _hostingEnvironment;

        #endregion

        #region --- Constructor(s) ---

        public ItemCategoriesController(IItemCategoryService itemCategoryService, IWebHostEnvironment Environment)
        {
            _itemCategoryService = itemCategoryService;
            _hostingEnvironment = Environment;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Categories")]
        [PermissionKey("Product.ItemCategory.List")]
        public IActionResult List()
        {
            return Ok(_itemCategoryService.GetTree());
        }


        [HttpGet("Category")]
        public IActionResult GetAllCategory()
        {
            return Ok(_itemCategoryService.GetAllCategory());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_itemCategoryService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Category")]
        [PermissionKey("Product.ItemCategory.Create")]
        public IActionResult Create([FromForm] ItemCategory itemCategory)
        {
            if (_itemCategoryService.NameExists(itemCategory))
                return Conflict("Category already exists");

            var newcat = _itemCategoryService.Create(itemCategory);

            _itemCategoryService.SaveImage(newcat, Request);

            return Ok(newcat);
        }


        [HttpPut]
        [DisplayName("Update Category")]
        [PermissionKey("Product.ItemCategory.Update")]
        public IActionResult Update([FromForm] ItemCategory itemCategory)
        {
            if (_itemCategoryService.NameExists(itemCategory))
                return Conflict("Category already exists");

            var newcat = _itemCategoryService.Update(itemCategory);

            _itemCategoryService.SaveImage(newcat, Request);

            return Ok();
        }

        [HttpPost("{id}/Image")]
        [DisplayName("Update Category Image")]
        [PermissionKey("Product.ItemCategory.Update")]
        public IActionResult UploadImage(int id, [FromForm] IFormFile file)
        {
            return Ok(_itemCategoryService.UploadImage(id, file, Request));
        }

        [HttpPost("{id}/Image/ReprocessOriginal")]
        [DisplayName("Reprocess Category Image From Original")]
        [PermissionKey("Product.ItemCategory.Update")]
        public IActionResult ReprocessImageOriginal(int id)
        {
            _itemCategoryService.ReprocessImageOriginal(id);
            return Ok();
        }

        [HttpPost("{id}/Image/ProcessBgLocal")]
        [DisplayName("Process Category Background Removal (Local)")]
        [PermissionKey("Product.ItemCategory.Update")]
        public async Task<IActionResult> ProcessImageBgLocal(int id)
        {
            var result = await _itemCategoryService.ProcessImageBgLocal(id);
            return Ok(result);
        }

        [HttpPost("{id}/Image/ProcessBgApi")]
        [DisplayName("Process Category Background Removal (API)")]
        [PermissionKey("Product.ItemCategory.Update")]
        public async Task<IActionResult> ProcessImageBgApi(int id)
        {
            var result = await _itemCategoryService.ProcessImageBgApi(id);
            return Ok(result);
        }

        [HttpPost("{id}/Image/Finalize")]
        [DisplayName("Finalize Category Image Version")]
        [PermissionKey("Product.ItemCategory.Update")]
        public async Task<IActionResult> FinalizeImage(int id, [FromBody] CategoryImageFinalizeReq req)
        {
            req.CategoryId = id;
            await _itemCategoryService.FinalizeImage(req);
            return Ok();
        }

        [HttpDelete("{id}/Image")]
        [DisplayName("Remove Category Image")]
        [PermissionKey("Product.ItemCategory.Update")]
        public IActionResult DeleteImage(int id)
        {
            _itemCategoryService.DeleteImage(id);
            return Ok();
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Category")]
        [PermissionKey("Product.ItemCategory.Delete")]
        public IActionResult Delete(int id)
        {
            _itemCategoryService.Delete(id);

            return Ok();
        }


        [HttpPost("Reorder")]
        [DisplayName("Reorder Category")]
        [PermissionKey("Product.ItemCategory.Reorder")]
        public IActionResult ReorderNode(ItemCategoryReorderReq dto)
        {
            try
            {
                _itemCategoryService.ReorderNode(dto);
                return Ok();
            }
            catch (Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }


        [HttpDelete("DeleteImg/{id}")]
        public IActionResult DeleteImg(int id)
        {
            _itemCategoryService.DeleteImage(id);
            return Ok();
        }

        #endregion
    }
}
