using KLS.API.Helpers;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Marketplace Sync Logs", GroupName = "Marketplace")]
    public class MarketSyncLogsController : BaseController
    {
        private readonly IMarketSyncLogService _service;

        public MarketSyncLogsController(IMarketSyncLogService service)
        {
            _service = service;
        }

        [HttpGet("{marketAccountId}")]
        [DisplayName("View Sync Logs")]
        [PermissionKey("Marketplace.SyncLog.List")]
        public IActionResult List(int marketAccountId)
        {
            return Ok(_service.GetByAccount(marketAccountId));
        }

        [HttpGet("Recent/{marketAccountId}")]
        public IActionResult Recent(int marketAccountId, int count = 20)
        {
            return Ok(_service.GetRecent(marketAccountId, count));
        }
    }
}
