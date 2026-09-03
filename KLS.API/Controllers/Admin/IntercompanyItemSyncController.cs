using KLS.API.Helpers;
using KLS.Common;
using KLS.Contract.Services;
using KLS.Models.Intercompany;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [DisplayName("Intercompany Item Sync")]
    public class IntercompanyItemSyncController : BaseController
    {
        private readonly IIntercompanyItemSyncService _intercompanyItemSyncService;
        private readonly ISystemSettingService _systemSettingService;

        public IntercompanyItemSyncController(
            IIntercompanyItemSyncService intercompanyItemSyncService,
            ISystemSettingService systemSettingService)
        {
            _intercompanyItemSyncService = intercompanyItemSyncService;
            _systemSettingService = systemSettingService;
        }

        private static void EnsureItemSyncEnabled(bool isEnabled)
        {
            if (!isEnabled)
                throw new UnauthorizedAccessException("Intercompany item sync is not enabled.");
        }

        [HttpGet("Targets")]
        [DisplayName("List Intercompany Item Sync Targets")]
        [PermissionKey("Product.Item.List")]
        public IActionResult Targets()
        {
            EnsureItemSyncEnabled(_systemSettingService.GetByKey<bool>(GlobalKey.INTERCOMPANY_ITEM_SYNC_ENABLED));
            return Ok(_intercompanyItemSyncService.Targets());
        }

        [HttpGet("Preview")]
        [DisplayName("Preview Intercompany Item Sync")]
        [PermissionKey("Product.Item.List")]
        public IActionResult Preview([FromQuery] string target)
        {
            EnsureItemSyncEnabled(_systemSettingService.GetByKey<bool>(GlobalKey.INTERCOMPANY_ITEM_SYNC_ENABLED));
            return Ok(_intercompanyItemSyncService.Preview(target));
        }

        [HttpPost("Run")]
        [DisplayName("Run Intercompany Item Sync")]
        [PermissionKey("Product.Item.Save")]
        public IActionResult Run([FromBody] IntercompanyItemSyncRunReq? req)
        {
            EnsureItemSyncEnabled(_systemSettingService.GetByKey<bool>(GlobalKey.INTERCOMPANY_ITEM_SYNC_ENABLED));
            return Ok(_intercompanyItemSyncService.Sync(req?.TargetCode ?? string.Empty));
        }

        [HttpPost("SyncCategories")]
        [DisplayName("Sync Intercompany Item Categories")]
        [PermissionKey("Product.Item.Save")]
        public IActionResult SyncCategories([FromBody] IntercompanyItemSyncRunReq? req)
        {
            EnsureItemSyncEnabled(_systemSettingService.GetByKey<bool>(GlobalKey.INTERCOMPANY_ITEM_SYNC_ENABLED));
            return Ok(_intercompanyItemSyncService.SyncCategories(req?.TargetCode ?? string.Empty));
        }

        [HttpPost("SyncStorages")]
        [DisplayName("Sync Intercompany Item Storages")]
        [PermissionKey("Product.Item.Save")]
        public IActionResult SyncStorages([FromBody] IntercompanyItemSyncRunReq? req)
        {
            EnsureItemSyncEnabled(_systemSettingService.GetByKey<bool>(GlobalKey.INTERCOMPANY_ITEM_SYNC_ENABLED));
            return Ok(_intercompanyItemSyncService.SyncStorages(req?.TargetCode ?? string.Empty));
        }

        [HttpGet("PreviewImages")]
        [DisplayName("Preview Intercompany Item Image Sync")]
        [PermissionKey("Product.ItemImage.List")]
        public IActionResult PreviewImages([FromQuery] string target)
        {
            EnsureItemSyncEnabled(_systemSettingService.GetByKey<bool>(GlobalKey.INTERCOMPANY_ITEM_SYNC_ENABLED));
            return Ok(_intercompanyItemSyncService.PreviewImages(target));
        }

        [HttpPost("SyncImages")]
        [DisplayName("Sync Intercompany Item Images")]
        [PermissionKey("Product.ItemImage.Upload")]
        public IActionResult SyncImages([FromBody] IntercompanyItemSyncRunReq? req)
        {
            EnsureItemSyncEnabled(_systemSettingService.GetByKey<bool>(GlobalKey.INTERCOMPANY_ITEM_SYNC_ENABLED));
            return Ok(_intercompanyItemSyncService.SyncImages(req?.TargetCode ?? string.Empty));
        }
    }
}
