using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Web
{
    [Route("api/web/[controller]")]
    public class SettingsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPortalModeService _portalModeService;
        private readonly ISystemSettingService _systemSettingService;

        #endregion

        #region --- Constructor(s) ---

        public SettingsController(IPortalModeService portalModeService, ISystemSettingService systemSettingService)
        {
            _portalModeService = portalModeService;
            _systemSettingService = systemSettingService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("public")]
        public IActionResult GetPublic()
        {
            return Ok(new WebPublicSettingsDto
            {
                PortalMode = _portalModeService.GetMode().ToString(),
                EnforceStockLimit = _systemSettingService.GetByKey<bool>(GlobalKey.WEB_ENFORCE_STOCK_LIMIT),
                CurrencyCode = "USD",
            });
        }

        #endregion
    }
}
