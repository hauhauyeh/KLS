using KLS.API.Helpers;
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

        public IntercompanyItemSyncController(IIntercompanyItemSyncService intercompanyItemSyncService)
        {
            _intercompanyItemSyncService = intercompanyItemSyncService;
        }

        [HttpGet("Targets")]
        [DisplayName("List Intercompany Item Sync Targets")]
        [PermissionKey("Product.Item.List")]
        public IActionResult Targets()
        {
            return Ok(_intercompanyItemSyncService.Targets());
        }

        [HttpGet("Preview")]
        [DisplayName("Preview Intercompany Item Sync")]
        [PermissionKey("Product.Item.List")]
        public IActionResult Preview([FromQuery] string target)
        {
            return Ok(_intercompanyItemSyncService.Preview(target));
        }

        [HttpPost("Run")]
        [DisplayName("Run Intercompany Item Sync")]
        [PermissionKey("Product.Item.Save")]
        public IActionResult Run([FromBody] IntercompanyItemSyncRunReq? req)
        {
            return Ok(_intercompanyItemSyncService.Sync(req?.TargetCode ?? string.Empty));
        }
    }
}
