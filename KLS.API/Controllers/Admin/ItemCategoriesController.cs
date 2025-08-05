using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    //[AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "ItemCategory Management", GroupName = "Admin")]
    public class ItemCategoriesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemCategoryService _itemCategoryService;

        #endregion

        #region --- Constructor(s) ---

        public ItemCategoriesController(IItemCategoryService itemCategoryService)
        {
            _itemCategoryService = itemCategoryService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Category")]
        public IActionResult GetAll()
        {
            return Ok(_itemCategoryService.GetAllCategoryTree());
        }


        [HttpGet("Category")]
        [DisplayName("List Category")]
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
        public IActionResult CreateItemCategory([FromBody] ItemCategory itemCategory)
        {
            if (_itemCategoryService.NameExists(itemCategory))
                return Conflict("Category already exists");

            return Ok(_itemCategoryService.CreateCategory(itemCategory));
        }


        [HttpPut]
        [DisplayName("Update Category")]
        public IActionResult UpdateItemCategory([FromBody] ItemCategory itemCategory)
        {
            if (_itemCategoryService.NameExists(itemCategory))
                return Conflict("Category already exists");

            return Ok(_itemCategoryService.UpdateCategory(itemCategory));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Category")]
        public IActionResult DeleteCategory(int id)
        {
            _itemCategoryService.DeleteItemCategory(id);

            return Ok();
        }

        #endregion
    }
}
