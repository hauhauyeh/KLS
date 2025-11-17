using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "ItemImage Management", GroupName = "Admin")]
    public class ItemImagesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemImageService _itemImageService;

        #endregion

        #region --- Constructor(s) ---

        public ItemImagesController(IItemImageService itemImageService)
        {
            _itemImageService = itemImageService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
