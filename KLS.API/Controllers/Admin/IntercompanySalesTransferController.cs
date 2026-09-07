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
    [DisplayName("Intercompany Sales Transfer")]
    public class IntercompanySalesTransferController : BaseController
    {
        private readonly IIntercompanySalesTransferService _intercompanySalesTransferService;
        private readonly ISystemSettingService _systemSettingService;

        public IntercompanySalesTransferController(
            IIntercompanySalesTransferService intercompanySalesTransferService,
            ISystemSettingService systemSettingService)
        {
            _intercompanySalesTransferService = intercompanySalesTransferService;
            _systemSettingService = systemSettingService;
        }

        private static void EnsureSalesTransferEnabled(bool isEnabled)
        {
            if (!isEnabled)
                throw new UnauthorizedAccessException("Intercompany sales transfer is not enabled.");
        }

        [HttpGet("Targets")]
        [DisplayName("List Intercompany Sales Transfer Targets")]
        [PermissionKey("Intercompany.SalesTransfer.View")]
        public IActionResult Targets()
        {
            EnsureSalesTransferEnabled(_systemSettingService.GetByKey<bool>(GlobalKey.INTERCOMPANY_SALES_TRANSFER_ENABLED));
            return Ok(_intercompanySalesTransferService.Targets());
        }

        [HttpGet("Preview")]
        [DisplayName("Preview Intercompany Sales Transfer")]
        [PermissionKey("Intercompany.SalesTransfer.View")]
        public IActionResult Preview([FromQuery] string target, [FromQuery] DateOnly fromShipDate, [FromQuery] DateOnly toShipDate)
        {
            EnsureSalesTransferEnabled(_systemSettingService.GetByKey<bool>(GlobalKey.INTERCOMPANY_SALES_TRANSFER_ENABLED));
            return Ok(_intercompanySalesTransferService.Preview(target, fromShipDate, toShipDate));
        }

        [HttpPost("Create")]
        [DisplayName("Create Intercompany Sales Transfer")]
        [PermissionKey("Intercompany.SalesTransfer.Create")]
        public IActionResult Create([FromBody] IntercompanySalesTransferCreateReq req)
        {
            EnsureSalesTransferEnabled(_systemSettingService.GetByKey<bool>(GlobalKey.INTERCOMPANY_SALES_TRANSFER_ENABLED));
            return Ok(_intercompanySalesTransferService.Create(req, UserContext.EmpId));
        }
    }
}
