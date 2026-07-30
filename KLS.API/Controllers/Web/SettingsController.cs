using KLS.Common;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

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
            var company = _companyService.GetDefault();
            var companyCode = NormalizeClientKey(company?.CompanyCode);

            return Ok(new WebPublicSettingsDto
            {
                ClientKey = companyCode,
                CompanyCode = companyCode,
                CompanyDisplayName = company?.DisplayName,
                PortalMode = _portalModeService.GetMode().ToString(),
                EnforceStockLimit = _systemSettingService.GetByKey<bool>(GlobalKey.WEB_ENFORCE_STOCK_LIMIT),
                UseSalesDocNumber = _systemSettingService.GetByKey<bool>(GlobalKey.SALES_DOC_NUMBER_DISPLAY_ENABLED),
                CurrencyCode = "USD",
                MetaTitle = seo?.MetaTitle,
                MetaTitleShort = seo?.MetaTitleShort,
                MetaDesc = seo?.MetaDesc,
                Keywords = seo?.Keywords,
                GoogleTagId = seo?.GoogleTagId,
                JsonLd = seo?.JsonLd,
                OrderCheckoutHour = _systemSettingService.GetByKey<int>(GlobalKey.WEB_ORDER_CHECKOUT_HOUR),
                ClientExperience = GetClientExperience(),
            });
        }

        private object? GetClientExperience()
        {
            var json = _systemSettingService.GetByKey<string>(GlobalKey.WEB_CLIENT_EXPERIENCE_JSON);

            if (string.IsNullOrWhiteSpace(json))
                return null;

            try
            {
                using var doc = JsonDocument.Parse(json);
                return doc.RootElement.Clone();
            }
            catch (JsonException)
            {
                return null;
            }
        }

        private static string? NormalizeClientKey(string? value)
        {
            var key = value?.Trim().ToUpperInvariant();
            return string.IsNullOrWhiteSpace(key) ? null : key;
        }

        #endregion
    }
}
