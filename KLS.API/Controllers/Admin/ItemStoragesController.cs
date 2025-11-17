using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Item Storage Management", GroupName = "Product")]
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
        [DisplayName("List Storage")]
        public IActionResult List()
        {
            return Ok(_itemStorageService.GetAllStorageTree());
        }


        [HttpGet("Storage")]
        public IActionResult GetAllStorages()
        {
            return Ok(_itemStorageService.GetAllStorages());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_itemStorageService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create ItemStorage")]
        public IActionResult Create([FromBody] ItemStorage itemStorage)
        {
            if (_itemStorageService.NameExists(itemStorage))
                return Conflict("Storage Name already exists");

            return Ok(_itemStorageService.CreateItemStorage(itemStorage));
        }


        [HttpPut]
        [DisplayName("Update ItemStorage")]
        public IActionResult Update([FromBody] ItemStorage itemStorage)
        {
            if (_itemStorageService.NameExists(itemStorage))
                return Conflict("Storage Name already exists");

            return Ok(_itemStorageService.UpdateItemStorage(itemStorage));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete ItemStorage")]
        public IActionResult Delete(int id)
        {
            _itemStorageService.DeleteItemStorage(id);

            return Ok();
        }

        #endregion
    }
}
