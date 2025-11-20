using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "ItemCategory Management", GroupName = "Product")]
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
        [DisplayName("List Category")]
        public IActionResult List()
        {
            return Ok(_itemCategoryService.GetAllCategoryTree());
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
        public IActionResult Create([FromForm] ItemCategory itemCategory)
        {
            if (_itemCategoryService.NameExists(itemCategory))
                return Conflict("Category already exists");

            var newcat = _itemCategoryService.CreateCategory(itemCategory);

            _itemCategoryService.SaveImage(newcat, Request);

            return Ok(newcat);
        }


        [HttpPut]
        [DisplayName("Update Category")]
        public IActionResult Update([FromForm] ItemCategory itemCategory)
        {
            if (_itemCategoryService.NameExists(itemCategory))
                return Conflict("Category already exists");

            var newcat = _itemCategoryService.UpdateCategory(itemCategory);

            _itemCategoryService.SaveImage(newcat, Request);

            return Ok();
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Category")]
        public IActionResult Delete(int id)
        {
            _itemCategoryService.DeleteCategory(id);

            return Ok();
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
