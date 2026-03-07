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
        public IActionResult Update([FromForm] ItemCategory itemCategory)
        {
            if (_itemCategoryService.NameExists(itemCategory))
                return Conflict("Category already exists");

            var newcat = _itemCategoryService.Update(itemCategory);

            _itemCategoryService.SaveImage(newcat, Request);

            return Ok();
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Category")]
        public IActionResult Delete(int id)
        {
            _itemCategoryService.Delete(id);

            return Ok();
        }


        [HttpPost("Reorder")]
        [DisplayName("Reorder Category")]
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
