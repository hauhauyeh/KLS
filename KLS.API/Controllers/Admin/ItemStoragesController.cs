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
            return Ok(_itemStorageService.GetAllStorages());
        }


        #endregion
    }
}
