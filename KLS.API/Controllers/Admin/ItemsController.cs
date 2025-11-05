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
    [Display(Name = "Item Management", GroupName = "Product")]
    public class ItemsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemService _itemService;

        #endregion

        #region --- Constructor(s) ---

        public ItemsController(ItemService itemService)
        {
            _itemService = itemService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Item")]
        public IActionResult List([FromQuery] ItemListReq itemListReq)
        {
            return Ok(_itemService.GetItems(itemListReq));
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] ItemSearchReq searchReq)
        {
            return Ok(_itemService.SearchItem(searchReq));
        }

        #endregion
    }
}
