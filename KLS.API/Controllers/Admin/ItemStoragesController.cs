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
    [Display(Name = "Storage Management", GroupName = "Product")]
    public class ItemStoragesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemStorageService _itemStorageService;

        #endregion

        #region --- Constructor(s) ---

        public ItemStoragesController(IItemStorageService itemStorageService)
        {
            _itemStorageService = itemStorageService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Storages")]
        [PermissionKey("Product.ItemStorage.List")]
        public IActionResult List()
        {
            return Ok(_itemStorageService.GetList());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_itemStorageService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Storage")]
        [PermissionKey("Product.ItemStorage.Create")]
        public IActionResult Create([FromBody] ItemStorage itemStorage)
        {
            if (_itemStorageService.NameExists(itemStorage))
                return Conflict("Storage Name already exists");

            return Ok(_itemStorageService.Create(itemStorage));
        }


        [HttpPut]
        [DisplayName("Update Storage")]
        [PermissionKey("Product.ItemStorage.Update")]
        public IActionResult Update([FromBody] ItemStorage itemStorage)
        {
            if (_itemStorageService.NameExists(itemStorage))
                return Conflict("Storage Name already exists");

            return Ok(_itemStorageService.Update(itemStorage));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Storage")]
        [PermissionKey("Product.ItemStorage.Delete")]
        public IActionResult Delete(int id)
        {
            _itemStorageService.Delete(id);

            return Ok();
        }

        #endregion
    }
}
