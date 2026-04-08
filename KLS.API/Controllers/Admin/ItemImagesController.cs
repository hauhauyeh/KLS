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
    [Display(Name = "Product Image Management", GroupName = "Product")]
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
        [DisplayName("List Images")]
        [PermissionKey("Product.ItemImage.List")]
        public IActionResult List(int itemId)
        {
            return Ok(_itemImageService.GetList(itemId));
        }


        [HttpPost]
        [DisplayName("Upload Image")]
        [PermissionKey("Product.ItemImage.Upload")]
        public IActionResult Upload([FromForm] ImageUploadReq uploadReq)
        {
            _itemImageService.Upload(uploadReq);
            return Ok();
        }


        [HttpDelete("{imageId}")]
        [DisplayName("Delete Image")]
        [PermissionKey("Product.ItemImage.Delete")]
        public IActionResult Delete(int imageId)
        {
            _itemImageService.Delete(imageId);
            return Ok();
        }

        #endregion
    }
}
