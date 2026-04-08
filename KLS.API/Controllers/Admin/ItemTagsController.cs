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
    [Display(Name = "Item Tag Management", GroupName = "Admin")]
    public class ItemTagsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemTagService _itemTagService;

        #endregion

        #region --- Constructor(s) ---

        public ItemTagsController(IItemTagService itemTagService)
        {
            _itemTagService = itemTagService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Item Tags")]
        [PermissionKey("Admin.ItemTag.List")]
        public IActionResult List()
        {
            return Ok(_itemTagService.GetList());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_itemTagService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Item Tag")]
        [PermissionKey("Admin.ItemTag.Create")]
        public IActionResult Create([FromBody] ItemTag itemTag)
        {
            if (_itemTagService.NameExists(itemTag))
                return Conflict("Tag name already exists");

            return Ok(_itemTagService.Create(itemTag));
        }


        [HttpPut]
        [DisplayName("Update Item Tag")]
        [PermissionKey("Admin.ItemTag.Update")]
        public IActionResult Update([FromBody] ItemTag itemTag)
        {
            if (_itemTagService.NameExists(itemTag))
                return Conflict("Tag name already exists");

            return Ok(_itemTagService.Update(itemTag));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Item Tag")]
        [PermissionKey("Admin.ItemTag.Delete")]
        public IActionResult Delete(int id)
        {
            _itemTagService.Delete(id);

            return Ok();
        }

        #endregion
    }
}
