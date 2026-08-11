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
                CompanyIdentity = BuildCompanyIdentity(company, companyCode),
                CompanyContact = BuildCompanyContact(company),
                PortalMode = _portalModeService.GetMode().ToString(),
                EnforceStockLimit = _systemSettingService.GetByKey<bool>(GlobalKey.WEB_ENFORCE_STOCK_LIMIT),
                UseSalesDocNumber = _systemSettingService.GetByKey<bool>(GlobalKey.SALES_DOC_NUMBER_DISPLAY_ENABLED),
                PublicProductListEnabled = _systemSettingService.GetByKey<bool>(GlobalKey.WEB_PUBLIC_PRODUCT_LIST_ENABLE),
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

        private static CompanyIdentityDto? BuildCompanyIdentity(Company? company, string? companyCode)
        {
            if (company == null)
                return null;

            return new CompanyIdentityDto
            {
                Code = companyCode,
                DisplayName = Clean(company.DisplayName),
                CompanyName = Clean(company.CompanyName),
                Website = Clean(company.Website),
                WebLogoUrl = Clean(company.WebLogoUrl),
                WebFaviconUrl = Clean(company.WebFaviconUrl),
            };
        }

        private static CompanyContactDto? BuildCompanyContact(Company? company)
        {
            if (company == null)
                return null;

            return new CompanyContactDto
            {
                Phone = Clean(company.Phone),
                SupportPhone = Clean(company.SupportPhone),
                Email = Clean(company.Email),
                SupportEmail = Clean(company.SupportEmail),
                SalesEmail = Clean(company.SalesEmail),
                PublicContactName = Clean(company.PublicContactName),
                PublicAddressName = Clean(company.PublicAddressName),
                AddressLine1 = Clean(company.AddressLine1),
                AddressLine2 = Clean(company.AddressLine2),
                City = Clean(company.City),
                State = Clean(company.State),
                ZipCode = Clean(company.ZipCode),
                CountryCode = Clean(company.CountryCode),
                FullAddress = Clean(company.FullAddress),
                BusinessHours = Clean(company.BusinessHours),
            };
        }

        private object? GetClientExperience()
        {
            return GetClientExperienceByKey(GlobalKey.WEB_CLIENT_EXPERIENCE_JSON);
        }

        private object? GetClientExperienceByKey(string settingKey)
        {
            var json = _systemSettingService.GetByKey<string>(settingKey);

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

        private static string? Clean(string? value)
        {
            var clean = value?.Trim();
            return string.IsNullOrWhiteSpace(clean) ? null : clean;
        }

        #endregion
    }
}
