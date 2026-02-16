using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
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

        [HttpGet("{itemId}")]
        public IActionResult List(int itemId)
        {
            return Ok(_itemImageService.GetList(itemId));
        }


        [HttpPost]
        public IActionResult Upload([FromForm] ImageUploadReq uploadReq)
        {
            _itemImageService.Upload(uploadReq);
            return Ok();
        }


        [HttpDelete("{imageId}")]
        public IActionResult Delete(int imageId)
        {
            _itemImageService.Delete(imageId);
            return Ok();
        }

        #endregion
    }
}
