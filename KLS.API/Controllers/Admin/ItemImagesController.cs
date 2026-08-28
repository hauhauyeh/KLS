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

        [HttpPost("{imageId}/reprocess-original")]
        [DisplayName("Reprocess Product Image From Original")]
        [PermissionKey("Product.ItemImage.Upload")]
        public IActionResult ReprocessOriginal(int imageId)
        {
            _itemImageService.ReprocessOriginal(imageId);
            return Ok();
        }

        [HttpPost("{imageId}/crop")]
        [DisplayName("Update Product Image Crop")]
        [PermissionKey("Product.ItemImage.Upload")]
        public IActionResult UpdateCrop(int imageId, [FromForm] ImageCropUpdateReq req)
        {
            _itemImageService.UpdateCrop(imageId, req);
            return Ok();
        }


        [HttpPost("{imageId}/process-bg-local")]
        [DisplayName("Process Background Removal (Local)")]
        public async Task<IActionResult> ProcessBgLocal(int imageId)
        {
            var result = await _itemImageService.ProcessBgLocal(imageId);
            return Ok(result);
        }


        [HttpPost("{imageId}/process-bg-api")]
        [DisplayName("Process Background Removal (API)")]
        public async Task<IActionResult> ProcessBgApi(int imageId)
        {
            var result = await _itemImageService.ProcessBgApi(imageId);
            return Ok(result);
        }


        [HttpPost("finalize")]
        [DisplayName("Finalize Image Version")]
        public async Task<IActionResult> Finalize([FromBody] ImageFinalizeReq req)
        {
            await _itemImageService.Finalize(req);
            return Ok();
        }


        /// <summary>
        /// One-time migration endpoint. Import legacy images from source folder.
        /// TODO: Remove this endpoint after migration is complete.
        /// </summary>
        [HttpPost("migrate")]
        [DisplayName("Migrate Legacy Images")]
        public IActionResult Migrate(
            [FromQuery] string sourceFolder,
            [FromQuery] bool confirm = false,
            [FromQuery] bool dryRun = false,
            [FromQuery] int limit = 0)
        {
            if (string.IsNullOrEmpty(sourceFolder))
                return BadRequest("sourceFolder query parameter is required.");

            // Dry-run doesn't need confirm
            if (!dryRun && !confirm)
                return BadRequest("Add &confirm=true to execute, or &dryRun=true to preview.");

            // Safety: reject paths outside the expected location
            var fullPath = Path.GetFullPath(sourceFolder);
            //if (!fullPath.StartsWith("C:\\Angular19\\", StringComparison.OrdinalIgnoreCase) &&
            //    !fullPath.StartsWith("C:/Angular19/", StringComparison.OrdinalIgnoreCase))
            //    return BadRequest("sourceFolder must be under C:\\Angular19\\");

            var result = _itemImageService.MigrateLegacyImages(fullPath, dryRun, limit);
            return Ok(result);
        }

        #endregion
    }
}
