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
        private readonly ICompanyService _companyService;

        #endregion

        #region --- Constructor(s) ---

        public SettingsController(IPortalModeService portalModeService, ISystemSettingService systemSettingService, ICompanyService companyService)
        {
            _portalModeService = portalModeService;
            _systemSettingService = systemSettingService;
            _companyService = companyService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("public")]
        public IActionResult GetPublic()
        {
            var seo = _companyService.GetSeo();

            return Ok(new WebPublicSettingsDto
            {
                PortalMode = _portalModeService.GetMode().ToString(),
                EnforceStockLimit = _systemSettingService.GetByKey<bool>(GlobalKey.WEB_ENFORCE_STOCK_LIMIT),
                CurrencyCode = "USD",
                MetaTitle = seo?.MetaTitle,
                MetaTitleShort = seo?.MetaTitleShort,
                MetaDesc = seo?.MetaDesc,
                Keywords = seo?.Keywords,
                GoogleTagId = seo?.GoogleTagId,
                JsonLd = seo?.JsonLd,
            });
        }

        #endregion
    }
}
