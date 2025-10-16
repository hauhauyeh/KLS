using KLS.API.Helpers;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Item Management", GroupName = "Admin")]
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



        #endregion
    }
}
